// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SparkLendFreezerMom } from "../src/SparkLendFreezerMom.sol";

import { SparkLendFreezerMomHarness } from "./harnesses/SparkLendFreezerMomHarness.sol";

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

contract RelyTests is SparkLendFreezerMomUnitTestBase {

    function test_rely_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/only-owner");
        freezer.rely(makeAddr("authedContract"));
    }

    function test_rely() public {
        address authedContract = makeAddr("authedContract");
        assertEq(freezer.wards(authedContract), 0);

        vm.prank(owner);
        freezer.rely(authedContract);

        assertEq(freezer.wards(authedContract), 1);
    }

}

contract DenyTests is SparkLendFreezerMomUnitTestBase {

    function test_deny_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/only-owner");
        freezer.deny(makeAddr("authedContract"));
    }

    function test_deny() public {
        address authedContract = makeAddr("authedContract");

        vm.prank(owner);
        freezer.rely(authedContract);

        assertEq(freezer.wards(authedContract), 1);

        vm.prank(owner);
        freezer.deny(authedContract);

        assertEq(freezer.wards(authedContract), 0);
    }

}

contract FreezeAllMarketsTests is SparkLendFreezerMomUnitTestBase {

    function test_freezeAllMarkets_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.freezeAllMarkets(false);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.freezeAllMarkets(true);
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
        freezer.freezeAllMarkets(true);

        vm.prank(caller);
        vm.expectCall(pool,         abi.encodePacked(poolSig));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset1, false)));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset2, false)));
        freezer.freezeAllMarkets(false);
    }

}

contract FreezeMarketTests is SparkLendFreezerMomUnitTestBase {

    address reserve = makeAddr("reserve");

    function test_freezeMarket_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.freezeMarket(reserve, false);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.freezeMarket(reserve, true);
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
        freezer.freezeMarket(reserve, true);

        vm.prank(caller);
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(reserve, false)));
        freezer.freezeMarket(reserve, false);
    }

}

contract PauseAllMarketsTests is SparkLendFreezerMomUnitTestBase {

    function test_pauseAllMarkets_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.pauseAllMarkets(false);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.pauseAllMarkets(true);
    }

    function test_pauseAllMarkets() public {
        address caller = makeAddr("caller");

        authority.__setCanCall(
            caller,
            address(freezer),
            freezer.pauseAllMarkets.selector,
            true
        );

        address asset1 = makeAddr("asset1");
        address asset2 = makeAddr("asset2");

        PoolMock(pool).__addAsset(asset1);
        PoolMock(pool).__addAsset(asset2);

        bytes4 poolSig   = PoolMock.getReservesList.selector;
        bytes4 configSig = ConfiguratorMock.setReservePause.selector;

        vm.prank(caller);
        vm.expectCall(pool,         abi.encodePacked(poolSig));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset1, true)));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset2, true)));
        freezer.pauseAllMarkets(true);

        vm.prank(caller);
        vm.expectCall(pool,         abi.encodePacked(poolSig));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset1, false)));
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(asset2, false)));
        freezer.pauseAllMarkets(false);
    }

}

contract PauseMarketTests is SparkLendFreezerMomUnitTestBase {

    address reserve = makeAddr("reserve");

    function test_pauseMarket_noAuth() public {
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.pauseMarket(reserve, false);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezer.pauseMarket(reserve, true);
    }

    function test_pauseMarket() public {
        address caller = makeAddr("caller");

        authority.__setCanCall(
            caller,
            address(freezer),
            freezer.pauseMarket.selector,
            true
        );

        bytes4 configSig = ConfiguratorMock.setReservePause.selector;

        vm.prank(caller);
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(reserve, true)));
        freezer.pauseMarket(reserve, true);

        vm.prank(caller);
        vm.expectCall(configurator, abi.encodePacked(configSig, abi.encode(reserve, false)));
        freezer.pauseMarket(reserve, false);
    }

}

contract SparkLendFreezerMomIsAuthorizedTest is Test {

    address public configurator;
    address public pool;
    address public owner;
    address public authedContract;

    AuthorityMock public authority;

    SparkLendFreezerMomHarness public freezer;

    address caller = makeAddr("caller");

    function setUp() public {
        owner          = makeAddr("owner");
        authedContract = makeAddr("authedContract");

        authority    = new AuthorityMock();
        configurator = address(new ConfiguratorMock());
        pool         = address(new PoolMock());
        freezer      = new SparkLendFreezerMomHarness(configurator, pool);

        freezer.rely(authedContract);
        freezer.setAuthority(address(authority));
        freezer.setOwner(owner);
    }

    function test_isAuthorized_internalCall() external {
        assertEq(freezer.isAuthorizedExternal(address(freezer), bytes4("0")), true);
    }

    function test_isAuthorized_srcIsOwner() external {
        assertEq(freezer.isAuthorizedExternal(owner, bytes4("0")), true);
    }

    function test_isAuthorized_srcIsWard() external {
        assertEq(freezer.isAuthorizedExternal(authedContract, bytes4("0")), true);
    }

    function test_isAuthorized_authorityIsZero() external {
        vm.prank(owner);
        freezer.setAuthority(address(0));
        assertEq(freezer.isAuthorizedExternal(caller, bytes4("0")), false);
    }

    function test_isAuthorized_canCall() external {
        vm.prank(owner);
        authority.__setCanCall(caller, address(freezer), bytes4("0"), true);

        vm.expectCall(
            address(authority),
            abi.encodePacked(
                AuthorityMock.canCall.selector,
                abi.encode(caller, address(freezer), bytes4("0"))
            )
        );
        assertEq(freezer.isAuthorizedExternal(caller, bytes4("0")), true);
    }

}

contract EventTests is SparkLendFreezerMomUnitTestBase {

    event FreezeMarket(address indexed reserve, bool freeze);
    event PauseMarket(address indexed reserve, bool pause);
    event SetOwner(address indexed oldOwner, address indexed newOwner);
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    function test_setAuthority_eventData() external {
        address newAuthority = makeAddr("newAuthority");

        vm.prank(owner);
        vm.expectEmit(address(freezer));
        emit SetAuthority(address(authority), newAuthority);
        freezer.setAuthority(newAuthority);
    }

    function test_setOwner_eventData() external {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        vm.expectEmit(address(freezer));
        emit SetOwner(owner, newOwner);
        freezer.setOwner(newOwner);
    }

    function test_rely_eventData() external {
        address authedContract = makeAddr("authedContract");

        vm.prank(owner);
        vm.expectEmit(address(freezer));
        emit Rely(authedContract);
        freezer.rely(authedContract);
    }

    function test_deny_eventData() external {
        address authedContract = makeAddr("authedContract");

        vm.prank(owner);
        vm.expectEmit(address(freezer));
        emit Deny(authedContract);
        freezer.deny(authedContract);
    }

    function test_freezeMarket_eventData() public {
        address caller = makeAddr("caller");
        address asset  = makeAddr("asset");

        authority.__setCanCall(
            caller,
            address(freezer),
            freezer.freezeMarket.selector,
            true
        );

        vm.prank(caller);
        emit FreezeMarket(asset, true);
        freezer.freezeMarket(asset, true);

        vm.prank(caller);
        emit FreezeMarket(asset, false);
        freezer.freezeMarket(asset, false);
    }

    function test_freezeAllMarkets_eventData() public {
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

        vm.prank(caller);
        vm.expectEmit(address(freezer));
        emit FreezeMarket(asset1, true);
        vm.expectEmit(address(freezer));
        emit FreezeMarket(asset2, true);
        freezer.freezeAllMarkets(true);

        vm.prank(caller);
        vm.expectEmit(address(freezer));
        emit FreezeMarket(asset1, false);
        vm.expectEmit(address(freezer));
        emit FreezeMarket(asset2, false);
        freezer.freezeAllMarkets(false);
    }

    function test_pauseMarket_eventData() public {
        address caller = makeAddr("caller");
        address asset  = makeAddr("asset");

        authority.__setCanCall(
            caller,
            address(freezer),
            freezer.pauseMarket.selector,
            true
        );

        vm.prank(caller);
        emit PauseMarket(asset, true);
        freezer.pauseMarket(asset, true);

        vm.prank(caller);
        emit PauseMarket(asset, false);
        freezer.pauseMarket(asset, false);
    }

    function test_pauseAllMarkets_eventData() public {
        address caller = makeAddr("caller");

        authority.__setCanCall(
            caller,
            address(freezer),
            freezer.pauseAllMarkets.selector,
            true
        );

        address asset1 = makeAddr("asset1");
        address asset2 = makeAddr("asset2");

        PoolMock(pool).__addAsset(asset1);
        PoolMock(pool).__addAsset(asset2);

        vm.prank(caller);
        vm.expectEmit(address(freezer));
        emit PauseMarket(asset1, true);
        vm.expectEmit(address(freezer));
        emit PauseMarket(asset2, true);
        freezer.pauseAllMarkets(true);

        vm.prank(caller);
        vm.expectEmit(address(freezer));
        emit PauseMarket(asset1, false);
        vm.expectEmit(address(freezer));
        emit PauseMarket(asset2, false);
        freezer.pauseAllMarkets(false);
    }

}
