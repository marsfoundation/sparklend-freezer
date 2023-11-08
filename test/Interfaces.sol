// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface IAuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);

    function hat() external view returns (address);

    function lock(uint256 amount) external;

    function vote(address[] calldata slate) external;

    function lift(address target) external;
}

interface IACLManagerLike {
    function addRiskAdmin(address target) external;
}

interface IPoolDataProviderLike {
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );
}
