// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SafeERC20 } from "lib/erc20-helpers/src/SafeERC20.sol";
import { IERC20 }    from "lib/erc20-helpers/src/interfaces/IERC20.sol";

import { SparkLendFreezerMom } from "src/SparkLendFreezerMom.sol";

import { EmergencySpell_SparkLend_FreezeSingleAsset as FreezeSingleAssetSpell }
    from "src/spells/EmergencySpell_SparkLend_FreezeSingleAsset.sol";

import { EmergencySpell_SparkLend_FreezeAllAssets as FreezeAllAssetsSpell }
    from "src/spells/EmergencySpell_SparkLend_FreezeAllAssets.sol";

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

    IAuthorityLike    authority    = IAuthorityLike(AUTHORITY);
    IACLManager       aclManager   = IACLManager(ACL_MANAGER);
    IPool             pool         = IPool(POOL);
    IPoolConfigurator poolConfig   = IPoolConfigurator(POOL_CONFIG);
    IPoolDataProvider dataProvider = IPoolDataProvider(DATA_PROVIDER);

    SparkLendFreezerMom freezer;

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18_572_000);

        freezer = new SparkLendFreezerMom(POOL_CONFIG, POOL);

        freezer.setAuthority(AUTHORITY);
        freezer.setOwner(PAUSE_PROXY);
    }

    function _vote(address spell) internal {
        uint256 amount = 1_000_000 ether;

        deal(MKR, mkrWhale, amount);

        vm.startPrank(mkrWhale);
        IERC20(MKR).approve(AUTHORITY, amount);
        authority.lock(amount);

        address[] memory slate = new address[](1);
        slate[0] = spell;
        authority.vote(slate);

        vm.roll(block.number + 1);

        authority.lift(spell);

        vm.stopPrank();

        assertTrue(authority.hat() == spell);
    }

    // NOTE: For all checks, not checking pool.swapBorrowRateMode() since stable rate
    //       isn't enabled on any reserve.
    function _checkUserActionsUnfrozen(
        address asset,
        uint256 supplyAmount,
        uint256 withdrawAmount,
        uint256 borrowAmount,
        uint256 repayAmount
    )
        internal
    {
        assertEq(_isFrozen(asset), false);

        // Make a new address for each asset to avoid side effects, eg. siloed borrowing
        address sparkUser = makeAddr(string.concat(IERC20(asset).name(), " user"));

        // If asset is not enabled as collateral, post enough WETH to ensure that the
        // reserve asset can be borrowed.
        // TODO: Remove LTV check once DAI spell goes through
        if (!_usageAsCollateralEnabled(asset) || _ltv(asset) == 1) {
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

contract FreezeSingleAssetSpellFailures is IntegrationTestsBase {

    FreezeSingleAssetSpell freezeAssetSpell;

    function setUp() public override {
        super.setUp();
        freezeAssetSpell = new FreezeSingleAssetSpell(address(freezer), WETH);
    }

    function test_cannotCallWithoutHat() external {
        assertTrue(authority.hat() != address(freezeAssetSpell));
        assertTrue(
            !authority.canCall(
                address(freezeAssetSpell),
                address(freezer),
                freezer.freezeMarket.selector
            )
        );

        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezeAssetSpell.freeze();
    }

    function test_cannotCallWithoutRoleSetup() external {
        _vote(address(freezeAssetSpell));

        assertTrue(authority.hat() == address(freezeAssetSpell));
        assertTrue(
            authority.canCall(
                address(freezeAssetSpell),
                address(freezer),
                freezer.freezeMarket.selector
            )
        );

        vm.expectRevert(bytes("4"));  // CALLER_NOT_RISK_OR_POOL_ADMIN
        freezeAssetSpell.freeze();
    }

}

contract FreezeAllAssetsSpellFailures is IntegrationTestsBase {

    FreezeAllAssetsSpell freezeAllAssetsSpell;

    function setUp() public override {
        super.setUp();
        freezeAllAssetsSpell = new FreezeAllAssetsSpell(address(freezer));
    }

    function test_cannotCallWithoutHat() external {
        assertTrue(authority.hat() != address(freezeAllAssetsSpell));
        assertTrue(
            !authority.canCall(
                address(freezeAllAssetsSpell),
                address(freezer),
                freezer.freezeAllMarkets.selector
            )
        );

        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezeAllAssetsSpell.freeze();
    }

    function test_cannotCallWithoutRoleSetup() external {
        _vote(address(freezeAllAssetsSpell));

        assertTrue(authority.hat() == address(freezeAllAssetsSpell));
        assertTrue(
            authority.canCall(
                address(freezeAllAssetsSpell),
                address(freezer),
                freezer.freezeAllMarkets.selector
            )
        );

        vm.expectRevert(bytes("4"));  // CALLER_NOT_RISK_OR_POOL_ADMIN
        freezeAllAssetsSpell.freeze();
    }

}

contract FreezeSingleAssetSpellTest is IntegrationTestsBase {

    using SafeERC20 for IERC20;

    address[] public untestedReserves;

    function setUp() public override {
        super.setUp();
        vm.prank(SPARK_PROXY);
        aclManager.addRiskAdmin(address(freezer));
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

            uint256 decimals = IERC20(asset).decimals();

            uint256 supplyAmount   = 1_000 * 10 ** decimals;
            uint256 withdrawAmount = 1 * 10 ** decimals;
            uint256 borrowAmount   = 2 * 10 ** decimals;
            uint256 repayAmount    = 1 * 10 ** decimals;

            uint256 snapshot = vm.snapshot();

            address freezeAssetSpell
                = address(new FreezeSingleAssetSpell(address(freezer), asset));

            // Setup spell, max out supply caps so that they aren't hit during test
            _vote(freezeAssetSpell);

            vm.startPrank(SPARK_PROXY);
            poolConfig.setSupplyCap(asset, 68_719_476_735);  // MAX_SUPPLY_CAP
            poolConfig.setBorrowCap(asset, 68_719_476_735);  // MAX_BORROW_CAP
            vm.stopPrank();

            _checkUserActionsUnfrozen(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.prank(randomUser);  // Demonstrate no ACL in spell
            FreezeSingleAssetSpell(freezeAssetSpell).freeze();

            _checkUserActionsFrozen(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.prank(SPARK_PROXY);
            poolConfig.setReserveFreeze(asset, false);

            _checkUserActionsUnfrozen(
                asset,
                supplyAmount,
                withdrawAmount,
                borrowAmount,
                repayAmount
            );

            vm.revertTo(snapshot);
        }

        assertEq(untestedReserves.length, 1);
        assertEq(untestedReserves[0],     0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);  // WBTC
    }

}

contract FreezeAllAssetsSpellTest is IntegrationTestsBase {

    using SafeERC20 for IERC20;

    address[] public untestedReserves;

    function setUp() public override {
        super.setUp();
        vm.prank(SPARK_PROXY);
        aclManager.addRiskAdmin(address(freezer));
    }

    function test_freezeAllAssetsSpell() external {
        address[] memory reserves = pool.getReservesList();

        assertEq(reserves.length, 9);

        uint256 supplyAmount   = 1_000;
        uint256 withdrawAmount = 1;
        uint256 borrowAmount   = 2;
        uint256 repayAmount    = 1;

        address freezeAllAssetsSpell = address(new FreezeAllAssetsSpell(address(freezer)));

        // Setup spell
        _vote(freezeAllAssetsSpell);

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
            poolConfig.setSupplyCap(asset, 68_719_476_735);  // MAX_SUPPLY_CAP
            poolConfig.setBorrowCap(asset, 68_719_476_735);  // MAX_BORROW_CAP
            vm.stopPrank();

            _checkUserActionsUnfrozen(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }

        assertEq(untestedReserves.length, 1);
        assertEq(untestedReserves[0],     0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);  // WBTC

        // Freeze all assets in the protocol
        vm.prank(randomUser);  // Demonstrate no ACL in spell
        FreezeSingleAssetSpell(freezeAllAssetsSpell).freeze();

        // Check that protocol is working as expected after the freeze spell for all assets
        for (uint256 i = 0; i < reserves.length; i++) {
            if (reserves[i] == untestedReserves[0]) {
                continue;
            }

            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            // Check all assets, including unfrozen ones from start
            _checkUserActionsFrozen(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }

        // Undo all freezes, including WBTC and make sure that protocol is back to working
        // as expected
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset    = reserves[i];
            uint256 decimals = IERC20(asset).decimals();

            vm.prank(SPARK_PROXY);
            poolConfig.setReserveFreeze(asset, false);

            _checkUserActionsUnfrozen(
                asset,
                supplyAmount * 10 ** decimals,
                withdrawAmount * 10 ** decimals,
                borrowAmount * 10 ** decimals,
                repayAmount * 10 ** decimals
            );
        }
    }

}
