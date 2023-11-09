// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SafeERC20 } from "lib/erc20-helpers/src/SafeERC20.sol";
import { IERC20 }    from "lib/erc20-helpers/src/interfaces/IERC20.sol";

import { SparkLendFreezerMom } from "src/SparkLendFreezerMom.sol";
import { FreezeWETH }          from "src/FreezeWETH.sol";

import { IACLManager }       from "lib/aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IPoolConfigurator } from "lib/aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import { IPoolDataProvider } from "lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";
import { IPool }             from "lib/aave-v3-core/contracts/interfaces/IPool.sol";

import { IAuthorityLike } from "test/Interfaces.sol";

contract IntegrationTests is Test {

    using SafeERC20 for IERC20;

    address constant ACL_MANAGER   = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address constant AUTHORITY     = 0x9eF05f7F6deB616fd37aC3c959a2dDD25A54E4F5;
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

    SparkLendFreezerMom freezer;
    FreezeWETH          freezeWeth;

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);

        freezer    = new SparkLendFreezerMom(POOL_CONFIG, POOL, AUTHORITY);
        freezeWeth = new FreezeWETH(address(freezer));

        freezer.setOwner(PAUSE_PROXY);
    }

    function test_cannotCallWithoutHat() external {
        assertTrue(authority.hat() != address(freezeWeth));
        assertTrue(
            !authority.canCall(address(freezeWeth), address(freezer), freezer.freezeMarket.selector)
        );

        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezeWeth.freeze();
    }

    function test_cannotCallWithoutRoleSetup() external {
        _vote(address(freezeWeth));

        assertTrue(authority.hat() == address(freezeWeth));
        assertTrue(
            authority.canCall(address(freezeWeth), address(freezer), freezer.freezeMarket.selector)
        );

        vm.expectRevert(bytes("4"));  // CALLER_NOT_RISK_OR_POOL_ADMIN
        freezeWeth.freeze();
    }

    function test_freezeWeth() external {
        _vote(address(freezeWeth));

        vm.prank(SPARK_PROXY);
        aclManager.addRiskAdmin(address(freezer));

        assertEq(_isFrozen(WETH), false);

        deal(WETH, sparkUser, 20e18);  // Deal enough for 2 supplies

        // 1. Check supply/borrow before freeze
        // NOTE: For all checks, not checking pool.swapBorrowRateMode() since stable rate
        //       isn't enabled on any reserve.

        vm.startPrank(sparkUser);

        // User can supply
        IERC20(WETH).safeApprove(POOL, 10e18);
        pool.supply(WETH, 10e18, sparkUser, 0);

        // User can borrow
        pool.borrow(WETH, 1e18, 2, 0, sparkUser);

        vm.stopPrank();

        // 2. Freeze market

        vm.prank(randomUser);  // Demonstrate no ACL in spell
        freezeWeth.freeze();

        assertEq(_isFrozen(WETH), true);

        // 3. Check supply/borrow after freeze

        vm.startPrank(sparkUser);

        // User can't supply
        IERC20(WETH).safeApprove(POOL, 10e18);
        vm.expectRevert(bytes("28"));  // RESERVE_FROZEN
        pool.supply(WETH, 10e18, sparkUser, 0);

        // User can't borrow
        vm.expectRevert(bytes("28"));  // RESERVE_FROZEN
        pool.borrow(WETH, 1e18, 2, 0, sparkUser);

        vm.stopPrank();

        // 4. Simulate spell after freeze, unfreezing market
        vm.prank(SPARK_PROXY);
        poolConfig.setReserveFreeze(WETH, false);

        assertEq(_isFrozen(WETH), false);

        // 5. Check supply/borrow after unfreeze

        vm.startPrank(sparkUser);

        // User can supply
        IERC20(WETH).safeApprove(POOL, 10e18);
        pool.supply(WETH, 10e18, sparkUser, 0);

        // User can borrow
        pool.borrow(WETH, 1e18, 2, 0, sparkUser);
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
        authority.lift(spell);

        vm.stopPrank();

        assertTrue(authority.hat() == spell);
    }

    function _isFrozen(address asset) internal view returns (bool isFrozen) {
        ( ,,,,,,,,, isFrozen ) = dataProvider.getReserveConfigurationData(asset);
    }

}
