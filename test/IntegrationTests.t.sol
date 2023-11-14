// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SafeERC20 } from "lib/erc20-helpers/src/SafeERC20.sol";
import { IERC20 }    from "lib/erc20-helpers/src/interfaces/IERC20.sol";

import { SparkLendFreezerMom } from "src/SparkLendFreezerMom.sol";
import { EmergencySpell_SparkLend_FreezeSingleAsset as FreezeSingleAssetSpell }
    from "src/spells/EmergencySpell_SparkLend_FreezeSingleAsset.sol";

import { IACLManager }       from "lib/aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IPoolConfigurator } from "lib/aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import { IPoolDataProvider } from "lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import { IPool }             from "lib/aave-v3-core/contracts/interfaces/IPool.sol";

import { IAuthorityLike } from "test/Interfaces.sol";

contract IntegrationTestsBase is Test {

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
    address sparkUser  = makeAddr("sparkUser");
    address randomUser = makeAddr("randomUser");

    IAuthorityLike    authority    = IAuthorityLike(AUTHORITY);
    IACLManager       aclManager   = IACLManager(ACL_MANAGER);
    IPool             pool         = IPool(POOL);
    IPoolConfigurator poolConfig   = IPoolConfigurator(POOL_CONFIG);
    IPoolDataProvider dataProvider = IPoolDataProvider(DATA_PROVIDER);

    SparkLendFreezerMom    freezer;

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl);

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

        deal(WETH, sparkUser, 1_000 ether);

        // Since not all reserves are collateral, post enough WETH to ensure all reserves
        // can be borrowed.
        vm.startPrank(sparkUser);
        IERC20(WETH).safeApprove(POOL, type(uint256).max);
        pool.supply(WETH, 1_000 ether, sparkUser, 0);
        vm.stopPrank();

        for (uint256 i = 0; i < reserves.length; i++) {
            // If the asset is frozen on mainnet, skip the test
            if (_isFrozen(reserves[i])) {
                untestedReserves.push(reserves[i]);
                continue;
            }

            uint256 snapshot = vm.snapshot();
            address freezeAssetSpell
                = address(new FreezeSingleAssetSpell(address(freezer), reserves[i]));

            _testFreezeAsset(freezeAssetSpell, reserves[i]);
            vm.revertTo(snapshot);
        }

        assertEq(untestedReserves.length, 1);
        assertEq(untestedReserves[0],     0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);  // WBTC
    }

    function _testFreezeAsset(address spell, address asset) internal {
        // 1. Setup spell, max out supply caps so that they aren't hit during test

        _vote(spell);

        vm.startPrank(SPARK_PROXY);
        poolConfig.setSupplyCap(asset, 68_719_476_735);  // MAX_SUPPLY_CAP
        poolConfig.setBorrowCap(asset, 68_719_476_735);  // MAX_BORROW_CAP
        vm.stopPrank();

        assertEq(_isFrozen(asset), false);

        uint256 decimals = IERC20(asset).decimals();

        uint256 supplyAmount   = 1_000 * 10 ** decimals;
        uint256 withdrawAmount = 1 * 10 ** decimals;
        uint256 borrowAmount   = 1 * 10 ** decimals;
        uint256 repayAmount    = 1 * 10 ** decimals / 2;  // 0.5

        deal(asset, sparkUser, supplyAmount * 2);  // Deal enough for 2 supplies

        // 2. Check user actions before freeze
        // NOTE: For all checks, not checking pool.swapBorrowRateMode() since stable rate
        //       isn't enabled on any reserve.

        vm.startPrank(sparkUser);

        IERC20(asset).safeApprove(POOL, type(uint256).max);

        // User can supply, borrow, repay, and withdraw
        pool.supply(asset, supplyAmount, sparkUser, 0);
        pool.withdraw(asset, withdrawAmount, sparkUser);

        if (_borrowingEnabled(asset)) {
            pool.borrow(asset, borrowAmount, 2, 0, sparkUser);
            pool.repay(asset, repayAmount, 2, sparkUser);
        }

        vm.stopPrank();

        // 3. Freeze market

        vm.prank(randomUser);  // Demonstrate no ACL in spell
        FreezeSingleAssetSpell(spell).freeze();

        assertEq(_isFrozen(asset), true);

        // 4. Check user actions after freeze

        vm.startPrank(sparkUser);

        // User can't supply
        vm.expectRevert(bytes("28"));  // RESERVE_FROZEN
        pool.supply(asset, supplyAmount, sparkUser, 0);

        // User can't borrow
        vm.expectRevert(bytes("28"));  // RESERVE_FROZEN
        pool.borrow(asset, borrowAmount, 2, 0, sparkUser);

        // User can still repay and withdraw
        if (_borrowingEnabled(asset)) {
            pool.repay(asset, repayAmount, 2, sparkUser);
        }
        pool.withdraw(asset, withdrawAmount, sparkUser);

        vm.stopPrank();

        // 5. Simulate spell after freeze, unfreezing market
        vm.prank(SPARK_PROXY);
        poolConfig.setReserveFreeze(asset, false);

        assertEq(_isFrozen(asset), false);

        // 6. Check user actions after unfreeze

        vm.startPrank(sparkUser);

        // User can supply, borrow, repay, and withdraw
        pool.supply(asset, supplyAmount, sparkUser, 0);
        pool.withdraw(asset, withdrawAmount, sparkUser);

        if (_borrowingEnabled(asset)) {
            pool.borrow(asset, borrowAmount, 2, 0, sparkUser);
            pool.repay(asset, repayAmount, 2, sparkUser);
        }
    }

    function _isFrozen(address asset) internal view returns (bool isFrozen) {
        ( ,,,,,,,,, isFrozen ) = dataProvider.getReserveConfigurationData(asset);
    }

    function _borrowingEnabled(address asset) internal view returns (bool borrowingEnabled) {
        ( ,,,,,, borrowingEnabled,,, ) = dataProvider.getReserveConfigurationData(asset);
    }

}
