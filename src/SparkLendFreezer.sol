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

    modifier auth {
        require(wards[msg.sender] == 1, "SparkLendFreezer/not-authorized");
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

    function freeze() external {
        require(canFreeze, "SparkLendFreezer/freeze-not-allowed");
        require(
            AuthorityLike(authority).canCall(msg.sender, address(this), msg.sig),
            "SparkLendFreezer/cannot-call"
        );

        address[] memory reserves = PoolLike(pool).getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            if (reserves[i] == address(0)) continue;
            PoolConfiguratorLike(poolConfigurator).setReserveFreeze(reserves[i], true);
        }

        canFreeze = false;
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
