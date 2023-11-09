// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

interface PoolConfiguratorLike {
    function setReserveFreeze(address asset, bool freeze) external;
}

interface PoolLike {
    function getReservesList() external view returns (address[] memory);
}

contract SparkLendFreezerMom is ISparkLendFreezerMom {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public immutable poolConfigurator;
    address public immutable pool;

    address public authority;
    address public owner;

    constructor(address poolConfigurator_, address pool_, address authority_) {
        poolConfigurator = poolConfigurator_;
        pool             = pool_;
        authority        = authority_;
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
    /*** Wards Functions                                                                        ***/
    /**********************************************************************************************/

    function setAuthority(address authority_) external override onlyOwner {
        emit SetAuthority(authority, authority_);
        authority = authority_;
    }


    function setOwner(address owner_) external override onlyOwner {
        emit SetOwner(owner, owner_);
        owner = owner_;
    }

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    function freezeAllMarkets() external override auth {
        address[] memory reserves = PoolLike(pool).getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            if (reserves[i] == address(0)) continue;
            PoolConfiguratorLike(poolConfigurator).setReserveFreeze(reserves[i], true);
        }
    }

    function freezeMarket(address reserve) external override auth {
        PoolConfiguratorLike(poolConfigurator).setReserveFreeze(reserve, true);
    }

    /**********************************************************************************************/
    /*** Internal Functions                                                                     ***/
    /**********************************************************************************************/

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        }
    }

}

