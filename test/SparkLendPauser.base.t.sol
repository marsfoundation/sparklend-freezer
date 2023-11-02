// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SparkLendPauser } from "../src/SparkLendPauser.sol";

contract ConfiguratorMock {
    function setPause(bool paused) external {}
}

contract SparkLendPauserUnitTestBase is Test {

    address public authority;
    address public configurator;
    address public ward;

    SparkLendPauser public pauser;

    function setUp() public {
        authority = makeAddr("authority");
        ward      = makeAddr("ward");

        configurator = address(new ConfiguratorMock());
        pauser       = new SparkLendPauser(configurator, authority);

        pauser.rely(ward);
        pauser.deny(address(this));
    }

    function test_deny_no_auth() public {
        vm.expectRevert("SparkLendPauser/not-ward");
        pauser.deny(ward);
    }

    function test_deny() public {
        assertEq(pauser.wards(ward), 1);

        vm.prank(ward);
        pauser.deny(ward);

        assertEq(pauser.wards(ward), 0);
    }

    function test_rely_no_auth() public {
        vm.expectRevert("SparkLendPauser/not-ward");
        pauser.rely(makeAddr("new ward"));
    }

    function test_rely() public {
        address newWard = makeAddr("new ward");
        assertEq(pauser.wards(newWard), 0);

        vm.prank(ward);
        pauser.rely(newWard);

        assertEq(pauser.wards(ward), 1);
    }

    function test_setAuthority_no_auth() public {
        vm.expectRevert("SparkLendPauser/not-ward");
        pauser.setAuthority(makeAddr("new authority"));
    }

    function test_setAuthority() public {
        address newAuthority = makeAddr("new authority");
        assertEq(pauser.authority(), authority);

        vm.prank(ward);
        pauser.setAuthority(newAuthority);

        assertEq(pauser.authority(), newAuthority);
    }

    function test_resetPause_no_auth() public {
        vm.expectRevert("SparkLendPauser/not-ward");
        pauser.setCanPause(false);
    }

    function test_setCanPause() public {
        assertEq(pauser.canPause(), true);

        vm.startPrank(ward);
        pauser.setCanPause(false);

        assertEq(pauser.canPause(), false);

        pauser.setCanPause(true);

        assertEq(pauser.canPause(), true);
    }

}
