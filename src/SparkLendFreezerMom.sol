// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

import { IPool }             from "aave-v3-core/contracts/interfaces/IPool.sol";
import { IPoolConfigurator } from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

contract SparkLendFreezerMom is ISparkLendFreezerMom {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public immutable override poolConfigurator;
    address public immutable override pool;

    address public override authority;
    address public override owner;
    
    mapping(address => uint256) public override wards;

    constructor(address poolConfigurator_, address pool_) {
        poolConfigurator = poolConfigurator_;
        pool             = pool_;
        owner            = msg.sender;

        emit SetOwner(address(0), msg.sender);
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier onlyOwner {
        require(msg.sender == owner, "SparkLendFreezerMom/only-owner");
        _;
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig), "SparkLendFreezerMom/not-authorized");
        _;
    }

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    function setAuthority(address authority_) external override onlyOwner {
        emit SetAuthority(authority, authority_);
        authority = authority_;
    }


    function setOwner(address owner_) external override onlyOwner {
        emit SetOwner(owner, owner_);
        owner = owner_;
    }

    function rely(address usr) external override onlyOwner {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external override onlyOwner {
        wards[usr] = 0;
        emit Deny(usr);
    }

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    function freezeAllMarkets(bool freeze) external override auth {
        address[] memory reserves = IPool(pool).getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            address reserve = reserves[i];
            IPoolConfigurator(poolConfigurator).setReserveFreeze(reserve, freeze);
            emit FreezeMarket(reserve, freeze);
        }
    }

    function freezeMarket(address reserve, bool freeze) external override auth {
        IPoolConfigurator(poolConfigurator).setReserveFreeze(reserve, freeze);
        emit FreezeMarket(reserve, freeze);
    }

    function pauseAllMarkets(bool pause) external override auth {
        address[] memory reserves = IPool(pool).getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            address reserve = reserves[i];
            IPoolConfigurator(poolConfigurator).setReservePause(reserve, pause);
            emit PauseMarket(reserve, pause);
        }
    }

    function pauseMarket(address reserve, bool pause) external override auth {
        IPoolConfigurator(poolConfigurator).setReservePause(reserve, pause);
        emit PauseMarket(reserve, pause);
    }

    /**********************************************************************************************/
    /*** Internal Functions                                                                     ***/
    /**********************************************************************************************/

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner || wards[src] == 1) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        }
    }

}

