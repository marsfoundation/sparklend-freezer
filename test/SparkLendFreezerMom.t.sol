// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SparkLendFreezerMom } from "../src/SparkLendFreezerMom.sol";

import { AuthorityMock, ConfiguratorMock, PoolMock } from "./Mocks.sol";

contract SparkLendFreezerMomUnitTestBase is Test {

    address public configurator;
    address public pool;
    address public owner;

    AuthorityMock public authority;

    SparkLendFreezerMom public freezer;

    function setUp() public {
        owner = makeAddr("owner");

        authority    = new AuthorityMock();
        configurator = address(new ConfiguratorMock());
        pool         = address(new PoolMock());
        freezer      = new SparkLendFreezerMom(configurator, pool);

        freezer.setAuthority(address(authority));
        freezer.setOwner(owner);
    }

}

contract ConstructorTests is SparkLendFreezerMomUnitTestBase {

    function test_constructor() public {
        freezer = new SparkLendFreezerMom(configurator, pool);

        assertEq(freezer.poolConfigurator(), configurator);
        assertEq(freezer.pool(),             pool);
        assertEq(freezer.owner(),            address(this));
    }

}

contract SetOwnerTests is SparkLendFreezerMomUnitTestBase {

    function test_setOwner_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/only-owner");
        freezer.setOwner(address(1));
    }

    function test_setOwner() public {
        address newOwner = makeAddr("newOwner");
        assertEq(freezer.owner(), owner);

        vm.prank(owner);
        freezer.setOwner(newOwner);

        assertEq(freezer.owner(), newOwner);
    }

}

contract SetAuthorityTests is SparkLendFreezerMomUnitTestBase {

    function test_setAuthority_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/only-owner");
        freezer.setAuthority(makeAddr("newAuthority"));
    }

    function test_setAuthority() public {
        address newAuthority = makeAddr("newAuthority");
        assertEq(freezer.authority(), address(authority));

        vm.prank(owner);
        freezer.setAuthority(newAuthority);

        assertEq(freezer.authority(), newAuthority);
    }

}

contract FreezeAllMarketsTests is SparkLendFreezerMomUnitTestBase {

    function test_freezeAllMarkets_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.freezeAllMarkets();
    }

    function test_freezeAllMarkets() public {
        address caller = makeAddr("caller");

        authority.__setCanCall(
            caller,
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

        vm.prank(caller);
        vm.expectCall(pool,         abi.encodePacked(poolSig));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset1, true)));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset2, true)));
        freezer.freezeAllMarkets();
    }

}

contract FreezeMarketTests is SparkLendFreezerMomUnitTestBase {

    address reserve = makeAddr("reserve");

    function test_freezeMarket_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.freezeMarket(reserve);
    }

    function test_freezeMarket() public {
        address caller = makeAddr("caller");

        authority.__setCanCall(
            caller,
            address(freezer),
            freezer.freezeMarket.selector,
            true
        );

        bytes4 configSig = ConfiguratorMock.setReserveFreeze.selector;

        vm.prank(caller);
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(reserve, true)));
        freezer.freezeMarket(reserve);
    }

}


