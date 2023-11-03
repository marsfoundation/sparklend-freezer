// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SparkLendFreezer } from "../src/SparkLendFreezer.sol";

import { ConfiguratorMock, PoolMock } from "./Mocks.sol";

contract SparkLendFreezerUnitTests is Test {

    address public authority;
    address public configurator;
    address public pool;
    address public ward;

    SparkLendFreezer public freezer;

    function setUp() public {
        authority = makeAddr("authority");
        ward      = makeAddr("ward");

        configurator = address(new ConfiguratorMock());
        pool         = address(new PoolMock());
        freezer       = new SparkLendFreezer(configurator, pool, authority);

        freezer.rely(ward);
        freezer.deny(address(this));
    }

    /********************/
    /*** `deny` Tests ***/
    /********************/

    function test_deny_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-ward");
        freezer.deny(ward);
    }

    function test_deny() public {
        assertEq(freezer.wards(ward), 1);

        vm.prank(ward);
        freezer.deny(ward);

        assertEq(freezer.wards(ward), 0);
    }

    /********************/
    /*** `rely` Tests ***/
    /********************/

    function test_rely_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-ward");
        freezer.rely(makeAddr("new ward"));
    }

    function test_rely() public {
        address newWard = makeAddr("new ward");
        assertEq(freezer.wards(newWard), 0);

        vm.prank(ward);
        freezer.rely(newWard);

        assertEq(freezer.wards(ward), 1);
    }

    /****************************/
    /*** `setAuthority` Tests ***/
    /****************************/

    function test_setAuthority_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-ward");
        freezer.setAuthority(makeAddr("new authority"));
    }

    function test_setAuthority() public {
        address newAuthority = makeAddr("new authority");
        assertEq(freezer.authority(), authority);

        vm.prank(ward);
        freezer.setAuthority(newAuthority);

        assertEq(freezer.authority(), newAuthority);
    }

    /**************************/
    /*** `setCanFreeze` Tests ***/
    /**************************/

    function test_setCanFreeze_no_auth() public {
        vm.expectRevert("SparkLendFreezer/not-ward");
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

    // /*********************/
    // /*** `pause` Tests ***/
    // /*********************/

    // function test_freeze_noAuth() public {
    //     assertEq(freezer.canPause(), true);

    //     vm.startPrank(ward);
    //     freezer.setCanFreeze(false);

    //     assertEq(freezer.canPause(), false);

    //     freezer.setCanFreeze(true);

    //     assertEq(freezer.canPause(), true);
    // }

    // function test_pause_cannotPause() public {
    //     vm.startPrank(ward);
    //     freezer.setCanFreeze(false);

    //     vm.expectRevert("SparkLendFreezer/pause-not-allowed");

    //     freezer.setCanFreeze(false);
    // }

}


