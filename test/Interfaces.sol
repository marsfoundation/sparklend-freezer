// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IAuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);

    function hat() external view returns (address);

    function lock(uint256 amount) external;

    function vote(address[] calldata slate) external;

    function lift(address target) external;
}
