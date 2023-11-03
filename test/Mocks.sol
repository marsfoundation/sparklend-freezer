// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract AuthorityMock {

    bool internal _allCanCall;

    mapping (address => mapping (address => mapping (bytes4 => bool))) internal callAllowed;

    function __setCanCall(address src, address dst, bytes4 sig, bool allowed) public {
        callAllowed[src][dst][sig] = allowed;
    }

    function _setAllCanCall(bool allCanCall_) public {
        _allCanCall = allCanCall_;
    }

    function canCall(address src, address dst, bytes4 sig) external view returns (bool) {
        return callAllowed[src][dst][sig] || _allCanCall;
    }

}

contract ConfiguratorMock {

    function setReserveFreeze(address asset, bool freeze) external {}

}

contract PoolMock {

    function getReservesList() external pure returns (address[] memory list) {
        list = new address[](1);

        list[0] = address(0x1);
    }

}


