// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezer } from "src/interfaces/ISparkLendFreezer.sol";

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

interface PoolConfiguratorLike {
    function setReserveFreeze(address asset, bool freeze) external;
}

interface PoolLike {
    function getReservesList() external view returns (address[] memory);
}

contract SparkLendFreezer is ISparkLendFreezer {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public immutable poolConfigurator;
    address public immutable pool;

    address public authority;

    bool public canFreeze;

    mapping (address => uint256) public override wards;

    constructor(address poolConfigurator_, address pool_, address authority_) {
        poolConfigurator = poolConfigurator_;
        pool             = pool_;
        authority        = authority_;

        wards[msg.sender] = 1;
        canFreeze = true;
        emit Rely(msg.sender);
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier auth {
        require(wards[msg.sender] == 1, "SparkLendFreezer/not-authorized");
        _;
    }

    modifier freezeCheck {
        require(canFreeze, "SparkLendFreezer/freeze-not-allowed");
        require(
            AuthorityLike(authority).canCall(msg.sender, address(this), msg.sig),
            "SparkLendFreezer/cannot-call"
        );
        _;
    }

    /**********************************************************************************************/
    /*** Wards Functions                                                                        ***/
    /**********************************************************************************************/

    function deny(address usr) external override auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function rely(address usr) external override auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function setAuthority(address authority_) external auth {
        address oldAuthority = authority;
        authority = authority_;
        emit SetAuthority(oldAuthority, authority_);
    }

    function setCanFreeze(bool canFreeze_) external auth {
        canFreeze = canFreeze_;
    }

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    function freezeAllMarkets() external freezeCheck {
        address[] memory reserves = PoolLike(pool).getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            if (reserves[i] == address(0)) continue;
            PoolConfiguratorLike(poolConfigurator).setReserveFreeze(reserves[i], true);
        }

        canFreeze = false;
    }

    function freezeMarket(address reserve) external freezeCheck {
        PoolConfiguratorLike(poolConfigurator).setReserveFreeze(reserve, true);

        canFreeze = false;
    }

}
