// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SparkLendFreezer } from "src/SparkLendFreezer.sol";
import { FreezeWETH }       from "src/FreezeWETH.sol";

import { IAuthorityLike } from "test/Interfaces.sol";

contract IntegrationTests is Test {

    address constant AUTHORITY   = 0x9eF05f7F6deB616fd37aC3c959a2dDD25A54E4F5;
    address constant MKR         = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address constant POOL        = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address constant POOL_CONFIG = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;

    address mkrWhale = makeAddr("mkrWhale");

    IAuthorityLike authority = IAuthorityLike(AUTHORITY);

    SparkLendFreezer freezer;
    FreezeWETH       freezeWeth;

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);

        freezer    = new SparkLendFreezer(POOL_CONFIG, POOL, AUTHORITY);
        freezeWeth = new FreezeWETH(address(freezer));

        freezer.rely(PAUSE_PROXY);
        freezer.deny(address(this));
    }

    function test_cannotCallWithoutHat() external {
        assertTrue(authority.hat() != address(freezeWeth));
        assertTrue(
            !authority.canCall(address(freezeWeth), address(freezer), freezer.freezeMarket.selector)
        );


    }

    function _vote(address spell) internal {
        deal(MKR, mkrWhale, 1_000_000 ether);

        vm.startPrank(mkrWhale);


    }

}
