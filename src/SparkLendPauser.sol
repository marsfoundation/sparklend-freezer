// SPDX-License-Identifier: AGPL-3.0-or-later

import { ISparkLendPauser } from "src/interfaces/ISparkLendPauser.sol";

interface ProxyLike {
    function exec(address target, bytes calldata args) external payable returns (bytes memory out);
}

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

interface IPoolConfiguratorLike {
    function setPoolPause(bool paused) external;
}

contract SparkLendPauser is ISparkLendPauser {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    address public immutable sparklendPoolConfigurator;

    address public authority;

    bool public canPause;

    mapping (address => uint256) public override wards;

    constructor(address sparklendPoolConfigurator_, address authority_) {
        sparklendPoolConfigurator = sparklendPoolConfigurator_;
        authority = authority_;
        wards[msg.sender] = 1;
        canPause = true;
        emit Rely(msg.sender);
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier onlyWards {
        require(wards[msg.sender] == 1, "SparkLendPauser/not-ward");
        _;
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig), "SparkLendPauser/not-authorized");
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

    function setCanPause(bool canPause_) external onlyWards {
        canPause = canPause_;
    }

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    function pause() external auth {
        require(canPause, "SparkLendPauser/pause-not-allowed");
        require(
            AuthorityLike(authority).canCall(msg.sender, address(this), msg.sig),
            "SparkLendPauser/not-authorized"
        );
        IPoolConfiguratorLike(sparklendPoolConfigurator).setPoolPause(true);
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
