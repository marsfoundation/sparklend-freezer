// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SparkLendFreezer } from "../src/SparkLendFreezer.sol";

import { AuthorityMock, ConfiguratorMock, PoolMock } from "./Mocks.sol";

contract SparkLendFreezerUnitTestBase is Test {

    address public configurator;
    address public pool;
    address public ward;

    AuthorityMock public authority;

    SparkLendFreezer public freezer;

    function setUp() public {
        ward = makeAddr("ward");

        authority    = new AuthorityMock();
        configurator = address(new ConfiguratorMock());
        pool         = address(new PoolMock());
        freezer      = new SparkLendFreezer(configurator, pool, address(authority));

        freezer.rely(ward);
        freezer.deny(address(this));
    }

}

contract SparkLendFreezerConstructorTests is SparkLendFreezerUnitTestBase {

    function test_constructor() public {
        freezer = new SparkLendFreezer(configurator, pool, address(authority));

        assertEq(freezer.poolConfigurator(),   configurator);
        assertEq(freezer.pool(),               pool);
        assertEq(freezer.authority(),          address(authority));
        assertEq(freezer.canFreeze(),          true);
        assertEq(freezer.wards(address(this)), 1);
    }

}

contract SparkLendFreezerDenyTests is SparkLendFreezerUnitTestBase {

    function test_deny_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-authorized");
        freezer.deny(ward);
    }

    function test_deny() public {
        assertEq(freezer.wards(ward), 1);

        vm.prank(ward);
        freezer.deny(ward);

        assertEq(freezer.wards(ward), 0);
    }

}

contract SparkLendFreezerRelyTests is SparkLendFreezerUnitTestBase {

    function test_rely_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-authorized");
        freezer.rely(makeAddr("new ward"));
    }

    function test_rely() public {
        address newWard = makeAddr("new ward");
        assertEq(freezer.wards(newWard), 0);

        vm.prank(ward);
        freezer.rely(newWard);

        assertEq(freezer.wards(ward), 1);
    }

}

contract SparkLendFreezerSetAuthorityTests is SparkLendFreezerUnitTestBase {

    function test_setAuthority_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-authorized");
        freezer.setAuthority(makeAddr("new authority"));
    }

    function test_setAuthority() public {
        address newAuthority = makeAddr("new authority");
        assertEq(freezer.authority(), address(authority));

        vm.prank(ward);
        freezer.setAuthority(newAuthority);

        assertEq(freezer.authority(), newAuthority);
    }

}

contract SparkLendFreezerSetCanFreezeTests is SparkLendFreezerUnitTestBase {

    /****************************/
    /*** `setCanFreeze` Tests ***/
    /****************************/

    function test_setCanFreeze_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-authorized");
        freezer.setCanFreeze(false);
    }

    function test_setCanFreeze() public {
        assertEq(freezer.canFreeze(), true);

        vm.startPrank(ward);
        freezer.setCanFreeze(false);

        assertEq(freezer.canFreeze(), false);

        freezer.setCanFreeze(true);

        assertEq(freezer.canFreeze(), true);
    }

}

contract SparkLendFreezerFreezeAllMarketsTests is SparkLendFreezerUnitTestBase {

    /**********************/
    /*** `freeze` Tests ***/
    /**********************/

    function test_freezeAllMarkets_notAllowed() public {
        vm.prank(ward);
        freezer.setCanFreeze(false);

        vm.expectRevert("SparkLendFreezer/freeze-not-allowed");
        freezer.freezeAllMarkets();
    }

    function test_freezeAllMarkets_noAuth() public {
        vm.expectRevert("SparkLendFreezer/cannot-call");
        freezer.freezeAllMarkets();
    }

    function test_freezeAllMarkets_cannotCallTwice() public {
        authority.__setCanCall(
            address(this),
            address(freezer),
            freezer.freezeAllMarkets.selector,
            true
        );

        freezer.freezeAllMarkets();

        vm.expectRevert("SparkLendFreezer/freeze-not-allowed");
        freezer.freezeAllMarkets();
    }

    function test_freezeAllMarkets() public {
        authority.__setCanCall(
            address(this),
            address(freezer),
            freezer.freezeAllMarkets.selector,
            true
        );

        address asset1 = makeAddr("asset1");
        address asset2 = makeAddr("asset2");

        PoolMock(pool).__addAsset(asset1);
        PoolMock(pool).__addAsset(asset2);

        bytes4 poolSig   = PoolMock.getReservesList.selector;
        bytes4 configSig = ConfiguratorMock.setReserveFreeze.selector;

        assertEq(freezer.canFreeze(), true);

        vm.expectCall(pool,         abi.encodePacked(poolSig));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset1, true)));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset2, true)));
        freezer.freezeAllMarkets();

        assertEq(freezer.canFreeze(), false);
    }

}


