// SPDX-License-Identifier: AGPL-3.0-or-later

import { ISparkLendFreezer } from "src/interfaces/ISparkLendFreezer.sol";

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

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

    modifier onlyWards {
        require(wards[msg.sender] == 1, "SparkLendFreezer/not-ward");
        _;
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig), "SparkLendFreezer/not-authorized");
        _;
    }

    /**********************************************************************************************/
    /*** Wards Functions                                                                        ***/
    /**********************************************************************************************/

    function deny(address usr) external override onlyWards {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function rely(address usr) external override onlyWards {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function setAuthority(address authority_) external onlyWards {
        address oldAuthority = authority;
        authority = authority_;
        emit SetAuthority(oldAuthority, authority_);
    }

    function setCanFreeze(bool canFreeze_) external onlyWards {
        canFreeze = canFreeze_;
    }

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    function freeze() external auth {
        require(canFreeze, "SparkLendFreezer/pause-not-allowed");

        address[] memory reserves = PoolLike(pool).getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            if (reserves[i] == address(0)) continue;
            PoolConfiguratorLike(poolConfigurator).setReserveFreeze(reserves[i], true);
        }
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (wards[src] == 1) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        }
    }

}
