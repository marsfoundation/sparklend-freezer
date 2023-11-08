// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IAuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);

    function hat() external view returns (address);
}
