// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISparkLendFreezerMom {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev   Event to log the freezing of a given market in SparkLend.
     *  @dev   NOTE: This event will fire even if the market is already frozen.
     *  @param reserve The address of the market reserve.
     */
    event FreezeMarket(address indexed reserve);

    /**
     *  @dev   Event to log the setting of a new owner.
     *  @param oldOwner The address of the previous owner.
     *  @param newOwner The address of the new owner.
     */
    event SetOwner(address indexed oldOwner, address indexed newOwner);

    /**
     *  @dev   Event to log the setting of a new authority.
     *  @param oldAuthority The address of the previous authority.
     *  @param newAuthority The address of the new authority.
     */
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);

    /**********************************************************************************************/
    /*** Storage Variables                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the address of the pool configurator.
     *  @return The address of the pool configurator.
     */
    function poolConfigurator() external view returns (address);

    /**
     *  @dev    Returns the address of the pool.
     *  @return The address of the pool.
     */
    function pool() external view returns (address);

    /**
     *  @dev    Returns the address of the authority.
     *  @return The address of the authority.
     */
    function authority() external view returns (address);

    /**
     *  @dev    Returns the address of the owner.
     *  @return The address of the owner.
     */
    function owner() external view returns (address);

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev   Function to set a new authority, permissioned to owner.
     * @param authority The address of the new authority.
     */
    function setAuthority(address authority) external;

    /**
     * @dev   Function to set a new owner, permissioned to owner.
     * @param owner The address of the new owner.
     */
    function setOwner(address owner) external;

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev   Function to freeze a specified market. Permissioned using the isAuthorized function
     *         which allows the owner, the freezer contract itself, or the `hat` in the Chief
     *         to call the function. Note that the `authority` in this contract is assumed to be
     *         the Chief in the MakerDAO protocol.
     *  @param reserve The address of the market to freeze.
     */
    function freezeMarket(address reserve) external;

    /**
     *  @dev Function to freeze all markets. Permissioned using the isAuthorized function
     *       which allows the owner, the freezer contract itself, or the `hat` in the Chief
     *       to call the function.
     */
    function freezeAllMarkets() external;

}
