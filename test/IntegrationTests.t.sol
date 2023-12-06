// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SafeERC20 } from "lib/erc20-helpers/src/SafeERC20.sol";
import { IERC20 }    from "lib/erc20-helpers/src/interfaces/IERC20.sol";

import { IExecuteOnceSpell }   from "src/interfaces/IExecuteOnceSpell.sol";
import { SparkLendFreezerMom } from "src/SparkLendFreezerMom.sol";

import { EmergencySpell_SparkLend_FreezeSingleAsset as FreezeSingleAssetSpell }
    from "src/spells/EmergencySpell_SparkLend_FreezeSingleAsset.sol";

import { EmergencySpell_SparkLend_FreezeAllAssets as FreezeAllAssetsSpell }
    from "src/spells/EmergencySpell_SparkLend_FreezeAllAssets.sol";

import { EmergencySpell_SparkLend_PauseSingleAsset as PauseSingleAssetSpell }
    from "src/spells/EmergencySpell_SparkLend_PauseSingleAsset.sol";

import { EmergencySpell_SparkLend_PauseAllAssets as PauseAllAssetsSpell }
    from "src/spells/EmergencySpell_SparkLend_PauseAllAssets.sol";

import { IACLManager }       from "lib/aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IPoolConfigurator } from "lib/aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import { IPoolDataProvider } from "lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import { IPool }             from "lib/aave-v3-core/contracts/interfaces/IPool.sol";

import { IAuthorityLike } from "test/Interfaces.sol";

contract IntegrationTestsBase is Test {

    using SafeERC20 for IERC20;

    address constant ACL_MANAGER   = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address constant AUTHORITY     = 0x0a3f6849f78076aefaDf113F5BED87720274dDC0;
    address constant DATA_PROVIDER = 0xFc21d6d146E6086B8359705C8b28512a983db0cb;
    address constant MKR           = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant PAUSE_PROXY   = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address constant POOL          = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address constant POOL_CONFIG   = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;
    address constant SPARK_PROXY   = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address constant WETH          = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address mkrWhale   = makeAddr("mkrWhale");
    address randomUser = makeAddr("randomUser");
    address multisig   = makeAddr("multisig");

    IAuthorityLike    authority    = IAuthorityLike(AUTHORITY);
    IACLManager       aclManager   = IACLManager(ACL_MANAGER);
    IPool             pool         = IPool(POOL);
    IPoolConfigurator poolConfig   = IPoolConfigurator(POOL_CONFIG);
    IPoolDataProvider dataProvider = IPoolDataProvider(DATA_PROVIDER);

    SparkLendFreezerMom freezerMom;

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18_706_418);

        freezerMom = new SparkLendFreezerMom(POOL_CONFIG, POOL);

        freezerMom.setAuthority(AUTHORITY);
        freezerMom.setOwner(PAUSE_PROXY);
        vm.prank(PAUSE_PROXY);
        freezerMom.rely(multisig);
    }

    // NOTE: For all checks, not checking pool.swapBorrowRateMode() since stable rate
    //       isn't enabled on any reserve.
    function _checkAllUserActionsAvailable(
        address asset,
        uint256 supplyAmount,
        uint256 withdrawAmount,
        uint256 borrowAmount,
        uint256 repayAmount
    )
        internal
    {
        assertEq(_isFrozen(asset), false);
        assertEq(_isPaused(asset), false);

        // Make a new address for each asset to avoid side effects, eg. siloed borrowing
        address sparkUser = makeAddr(string.concat(IERC20(asset).name(), " user"));

        // If asset is not enabled as collateral, post enough WETH to ensure that the
        // reserve asset can be borrowed.
        // NOTE: LTV check is necessary because LT of DAI is still 1.
        if (!_usageAsCollateralEnabled(asset) || _ltv(asset) == 0) {
            _supplyWethCollateral(sparkUser, 1_000 ether);
        }

        vm.startPrank(sparkUser);

        deal(asset, sparkUser, supplyAmount);
        IERC20(asset).safeApprove(POOL, type(uint256).max);

        // User can supply and withdraw collateral always
        pool.supply(asset, supplyAmount, sparkUser, 0);
        pool.withdraw(asset, withdrawAmount, sparkUser);

        // User can borrow and repay if borrowing is enabled
        if (_borrowingEnabled(asset)) {
            pool.borrow(asset, borrowAmount, 2, 0, sparkUser);
            pool.repay(asset, repayAmount, 2, sparkUser);
        }

        vm.stopPrank();
    }

    function _checkUserActionsFrozen(
        address asset,
        uint256 supplyAmount,
        uint256 withdrawAmount,
        uint256 borrowAmount,
        uint256 repayAmount
    )
        internal
    {
        assertEq(_isFrozen(asset), true);

        // Use same address that borrowed when unfrozen to repay debt
        address sparkUser = makeAddr(string.concat(IERC20(asset).name(), " user"));

        vm.startPrank(sparkUser);

        // User can't supply
        vm.expectRevert(bytes("28"));  // RESERVE_FROZEN
        pool.supply(asset, supplyAmount, sparkUser, 0);

        // User can't borrow
        vm.expectRevert(bytes("28"));  // RESERVE_FROZEN
        pool.borrow(asset, borrowAmount, 2, 0, sparkUser);

        // User can still withdraw collateral always
        pool.withdraw(asset, withdrawAmount, sparkUser);

        // User can repay if borrowing was enabled
        if (_borrowingEnabled(asset)) {
            pool.repay(asset, repayAmount, 2, sparkUser);
        }

        vm.stopPrank();
    }

    function _checkUserActionsPaused(
        address asset,
        uint256 supplyAmount,
        uint256 withdrawAmount,
        uint256 borrowAmount,
        uint256 repayAmount
    )
        internal
    {
        assertEq(_isPaused(asset), true);

        // Use same address that borrowed when unfrozen to repay debt
        address sparkUser = makeAddr(string.concat(IERC20(asset).name(), " user"));

        vm.startPrank(sparkUser);

        // User can't supply
        vm.expectRevert(bytes("29"));  // RESERVE_PAUSED
        pool.supply(asset, supplyAmount, sparkUser, 0);

        // User can't borrow
        vm.expectRevert(bytes("29"));  // RESERVE_PAUSED
        pool.borrow(asset, borrowAmount, 2, 0, sparkUser);

        // User can't withdraw collateral
        vm.expectRevert(bytes("29"));  // RESERVE_PAUSED
        pool.withdraw(asset, withdrawAmount, sparkUser);

        // User can't repay
        if (_borrowingEnabled(asset)) {
            vm.expectRevert(bytes("29"));  // RESERVE_PAUSED
            pool.repay(asset, repayAmount, 2, sparkUser);
        }

        vm.stopPrank();
    }

    function _supplyWethCollateral(address user, uint256 amount) internal {
        bool frozenWeth = _isFrozen(WETH);

        // Unfreeze WETH market if necessary
        if (frozenWeth) {
            vm.prank(SPARK_PROXY);
            poolConfig.setReserveFreeze(WETH, false);
        }

        // Supply WETH
        vm.startPrank(user);
        deal(WETH, user, amount);
        IERC20(WETH).safeApprove(POOL, type(uint256).max);
        pool.supply(WETH, amount, user, 0);
        vm.stopPrank();

        // If the WETH market was originally frozen, return it back to frozen state
        if (frozenWeth) {
            vm.prank(SPARK_PROXY);
            poolConfig.setReserveFreeze(WETH, false);
        }
    }

    function _isFrozen(address asset) internal view returns (bool isFrozen) {
        ( ,,,,,,,,, isFrozen ) = dataProvider.getReserveConfigurationData(asset);
    }

    function _isPaused(address asset) internal view returns (bool isPaused) {
        return dataProvider.getPaused(asset);
    }

    function _borrowingEnabled(address asset) internal view returns (bool borrowingEnabled) {
        ( ,,,,,, borrowingEnabled,,, ) = dataProvider.getReserveConfigurationData(asset);
    }

    function _usageAsCollateralEnabled(address asset)
        internal view returns (bool usageAsCollateralEnabled)
    {
        ( ,,,,, usageAsCollateralEnabled,,,, ) = dataProvider.getReserveConfigurationData(asset);
    }

    function _ltv(address asset) internal view returns (uint256 ltv) {
        ( , ltv,,,,,,,, ) = dataProvider.getReserveConfigurationData(asset);
    }

}

abstract contract ExecuteOnceSpellTests is IntegrationTestsBase {

    IExecuteOnceSpell spell;
    bool isPauseSpell;
    string contractName;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(SPARK_PROXY);
        aclManager.addEmergencyAdmin(address(freezerMom));
        aclManager.addRiskAdmin(address(freezerMom));
        vm.stopPrank();
    }

    function _vote() internal {
        _vote(address(spell));
    }

    function _vote(address _spell) internal {
        uint256 amount = 1_000_000 ether;

        deal(MKR, mkrWhale, amount);

        vm.startPrank(mkrWhale);
        IERC20(MKR).approve(AUTHORITY, amount);
        authority.lock(amount);

        address[] memory slate = new address[](1);
        slate[0] = _spell;
        authority.vote(slate);

        vm.roll(block.number + 1);

        authority.lift(_spell);

        vm.stopPrank();

        assertTrue(authority.hat() == _spell);
    }

    function test_cannotCallWithoutHat() external {
        assertTrue(authority.hat() != address(spell));
        assertTrue(
            !authority.canCall(
                address(spell),
                address(freezerMom),
                freezerMom.freezeMarket.selector
            )
        );

        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        spell.execute();
    }

    function test_cannotCallWithoutRoleSetup() external {
        vm.startPrank(SPARK_PROXY);
        aclManager.removeEmergencyAdmin(address(freezerMom));
        aclManager.removeRiskAdmin(address(freezerMom));
        vm.stopPrank();

        _vote();

        assertTrue(authority.hat() == address(spell));
        assertTrue(
            authority.canCall(
                address(spell),
                address(freezerMom),
                freezerMom.freezeMarket.selector
            )
        );

        if (isPauseSpell) vm.expectRevert(bytes("3"));  // CALLER_NOT_POOL_OR_EMERGENCY_ADMIN
        else vm.expectRevert(bytes("4"));               // CALLER_NOT_RISK_OR_POOL_ADMIN
        spell.execute();
    }

    function test_cannotCallTwice() external {
        _vote();

        assertTrue(authority.hat() == address(spell));
        assertTrue(
            authority.canCall(
                address(spell),
                address(freezerMom),
                freezerMom.freezeMarket.selector
            )
        );

        vm.startPrank(randomUser);  // Demonstrate no ACL in spell
        spell.execute();

        vm.expectRevert(bytes(string.concat(contractName, "/already-executed")));
        spell.execute();
    }

}

contract FreezeSingleAssetSpellTest is ExecuteOnceSpellTests {

    using SafeERC20 for IERC20;

    address[] public untestedReserves;

    function setUp() public override {
        super.setUp();

        // For the revert testing
        spell        = new FreezeSingleAssetSpell(address(freezerMom), WETH);
        isPauseSpell = false;
        contractName = "FreezeSingleAssetSpell";
    }

    function test_freezeAssetSpell_allAssets() external {
        address[] memory reserves = pool.getReservesList();

        assertEq(reserves.length, 9);

        for (uint256 i = 0; i < reserves.length; i++) {
            address asset = reserves[i];

            // If the asset is frozen on mainnet, skip the test
            if (_isFrozen(asset)) {
                untestedReserves.push(asset);
                continue;
            }

            assertEq(untestedReserves.length, 0);

            uint256 decimals = IERC20(asset).decimals();

            uint256 supplyAmount   = 1_000 * 10 ** decimals;
            uint256 withdrawAmount = 1 * 10 ** decimals;
            uint256 borrowAmount   = 2 * 10 ** decimals;
            uint256 repayAmount    = 1 * 10 ** decimals;

            uint256 snapshot = vm.snapshot();

            address freezeAssetSpell
                = address(new FreezeSingleAssetSpell(address(freezerMom), asset));

            // Setup spell, max out supply caps so that they aren't hit during test
            _vote(freezeAssetSpell);

            vm.startPrank(SPARK_PROXY);
            poolConfig.setSupplyCap(asset, 0);
            poolConfig.setBorrowCap(asset, 0);
            vm.stopPrank();

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            assertEq(FreezeSingleAssetSpell(freezeAssetSpell).executed(), false);

            vm.prank(randomUser);  // Demonstrate no ACL in spell
            FreezeSingleAssetSpell(freezeAssetSpell).execute();

            assertEq(FreezeSingleAssetSpell(freezeAssetSpell).executed(), true);

            _checkUserActionsFrozen(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.prank(SPARK_PROXY);
            poolConfig.setReserveFreeze(asset, false);

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.revertTo(snapshot);
        }
    }

}

contract FreezeAllAssetsSpellTest is ExecuteOnceSpellTests {

    using SafeERC20 for IERC20;

    address[] public untestedReserves;

    function setUp() public override {
        super.setUp();

        spell        = new FreezeAllAssetsSpell(address(freezerMom));
        isPauseSpell = false;
        contractName = "FreezeAllAssetsSpell";
    }

    function test_freezeAllAssetsSpell() external {
        address[] memory reserves = pool.getReservesList();

        assertEq(reserves.length, 9);

        uint256 supplyAmount   = 1_000;
        uint256 withdrawAmount = 1;
        uint256 borrowAmount   = 2;
        uint256 repayAmount    = 1;

        // Setup spell
        _vote();

        // Check that protocol is working as expected before spell for each asset
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            // If the asset is already frozen on mainnet, skip the test
            if (_isFrozen(asset)) {
                untestedReserves.push(asset);
                continue;
            }

            // Max out supply caps for this asset so that they aren't hit during test
            vm.startPrank(SPARK_PROXY);
            poolConfig.setSupplyCap(asset, 0);
            poolConfig.setBorrowCap(asset, 0);
            vm.stopPrank();

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }

        assertEq(untestedReserves.length, 0);

        assertEq(spell.executed(), false);

        // Freeze all assets in the protocol
        vm.prank(randomUser);  // Demonstrate no ACL in spell
        spell.execute();

        assertEq(spell.executed(), true);

        // Check that protocol is working as expected after the freeze spell for all assets
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            _checkUserActionsFrozen(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }

        // Undo all freezes and make sure that protocol is back to working
        // as expected
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            vm.prank(SPARK_PROXY);
            poolConfig.setReserveFreeze(asset, false);

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }
    }

}

contract PauseSingleAssetSpellTest is ExecuteOnceSpellTests {

    using SafeERC20 for IERC20;

    address[] public untestedReserves;

    function setUp() public override {
        super.setUp();

        // For the revert testing
        spell        = new PauseSingleAssetSpell(address(freezerMom), WETH);
        isPauseSpell = true;
        contractName = "PauseSingleAssetSpell";
    }

    function test_pauseAssetSpell_allAssets() external {
        address[] memory reserves = pool.getReservesList();

        assertEq(reserves.length, 9);

        for (uint256 i = 0; i < reserves.length; i++) {
            address asset = reserves[i];

            // If the asset is paused on mainnet, skip the test
            if (_isPaused(asset)) {
                untestedReserves.push(asset);
                continue;
            }

            assertEq(untestedReserves.length, 0);

            uint256 decimals = IERC20(asset).decimals();

            uint256 supplyAmount   = 1_000 * 10 ** decimals;
            uint256 withdrawAmount = 1 * 10 ** decimals;
            uint256 borrowAmount   = 2 * 10 ** decimals;
            uint256 repayAmount    = 1 * 10 ** decimals;

            uint256 snapshot = vm.snapshot();

            address pauseAssetSpell
                = address(new PauseSingleAssetSpell(address(freezerMom), asset));

            // Setup spell, max out supply caps so that they aren't hit during test
            _vote(pauseAssetSpell);

            vm.startPrank(SPARK_PROXY);
            poolConfig.setSupplyCap(asset, 0);
            poolConfig.setBorrowCap(asset, 0);
            vm.stopPrank();

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            assertEq(PauseSingleAssetSpell(pauseAssetSpell).executed(), false);

            vm.prank(randomUser);  // Demonstrate no ACL in spell
            PauseSingleAssetSpell(pauseAssetSpell).execute();

            assertEq(PauseSingleAssetSpell(pauseAssetSpell).executed(), true);

            _checkUserActionsPaused(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.prank(SPARK_PROXY);
            poolConfig.setReservePause(asset, false);

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.revertTo(snapshot);
        }
    }

}

contract PauseAllAssetsSpellTest is ExecuteOnceSpellTests {

    using SafeERC20 for IERC20;

    address[] public untestedReserves;

    function setUp() public override {
        super.setUp();

        spell        = new PauseAllAssetsSpell(address(freezerMom));
        isPauseSpell = true;
        contractName = "PauseAllAssetsSpell";
    }

    function test_pauseAllAssetsSpell() external {
        address[] memory reserves = pool.getReservesList();

        assertEq(reserves.length, 9);

        uint256 supplyAmount   = 1_000;
        uint256 withdrawAmount = 1;
        uint256 borrowAmount   = 2;
        uint256 repayAmount    = 1;

        // Setup spell
        _vote();

        // Check that protocol is working as expected before spell for each asset
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            // If the asset is already paused on mainnet, skip the test
            if (_isPaused(asset)) {
                untestedReserves.push(asset);
                continue;
            }

            // Max out supply caps for this asset so that they aren't hit during test
            vm.startPrank(SPARK_PROXY);
            poolConfig.setSupplyCap(asset, 0);
            poolConfig.setBorrowCap(asset, 0);
            vm.stopPrank();

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }

        assertEq(untestedReserves.length, 0);

        assertEq(spell.executed(), false);

        // Pause all assets in the protocol
        vm.prank(randomUser);  // Demonstrate no ACL in spell
        spell.execute();

        assertEq(spell.executed(), true);

        // Check that protocol is working as expected after the pause spell for all assets
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            _checkUserActionsPaused(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }

        // Undo all pauses and make sure that protocol is back to working
        // as expected
        for (uint256 i = 0; i < reserves.length; i++) {
            vm.prank(SPARK_PROXY);
            poolConfig.setReservePause(reserves[i], false);
        }

        // Need to unpause all first before checking that protocol is working
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            _checkAllUserActionsAvailable(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }
    }

}

contract MultisigTest is IntegrationTestsBase {

    function setUp() public override {
        super.setUp();

        vm.startPrank(SPARK_PROXY);

        aclManager.addRiskAdmin(address(freezerMom));
        aclManager.addEmergencyAdmin(address(freezerMom));

        vm.stopPrank();
    }

    function test_freezeSingleAsset() public {
        assertEq(_isFrozen(WETH), false);
        
        vm.prank(multisig);
        freezerMom.freezeMarket(WETH, true);

        assertEq(_isFrozen(WETH), true);
        
        vm.prank(multisig);
        freezerMom.freezeMarket(WETH, false);

        assertEq(_isFrozen(WETH), false);
    }

    function test_freezeAllAssets() public {
        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            assertEq(_isFrozen(reserves[i]), false);
        }
        
        vm.prank(multisig);
        freezerMom.freezeAllMarkets(true);

        for (uint256 i = 0; i < reserves.length; i++) {
            assertEq(_isFrozen(reserves[i]), true);
        }
        
        vm.prank(multisig);
        freezerMom.freezeAllMarkets(false);

        for (uint256 i = 0; i < reserves.length; i++) {
            assertEq(_isFrozen(reserves[i]), false);
        }
    }

    function test_pauseSingleAsset() public {
        assertEq(_isPaused(WETH), false);
        
        vm.prank(multisig);
        freezerMom.pauseMarket(WETH, true);

        assertEq(_isPaused(WETH), true);
        
        vm.prank(multisig);
        freezerMom.pauseMarket(WETH, false);

        assertEq(_isPaused(WETH), false);
    }

    function test_pauseAllAssets() public {
        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            assertEq(_isPaused(reserves[i]), false);
        }
        
        vm.prank(multisig);
        freezerMom.pauseAllMarkets(true);

        for (uint256 i = 0; i < reserves.length; i++) {
            assertEq(_isPaused(reserves[i]), true);
        }
        
        vm.prank(multisig);
        freezerMom.pauseAllMarkets(false);

        for (uint256 i = 0; i < reserves.length; i++) {
            assertEq(_isPaused(reserves[i]), false);
        }
    }

}
