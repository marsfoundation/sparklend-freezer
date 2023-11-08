// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISparkLendFreezer {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event SetOwner(address indexed oldOwner, address indexed newOwner);
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);

    /**
     *  @dev   Event emitted when a new admin is removed from the Conduit.
     *  @param usr The address of the user to remove.
     */
    event Deny(address indexed usr);

    /**
     *  @dev   Event emitted when a new admin is added to the Conduit.
     *  @param usr The address of the user to add.
     */
    event Rely(address indexed usr);

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
     *  @dev    Returns a 0 or 1 depending on if the user has been added as an admin.
     *          0 means the user is not an admin, 1 means the user is an admin.
     *  @return relied The value of the user's admin status.
     */
    function wards(address user) external view returns (uint256 relied);

    /**********************************************************************************************/
    /*** Wards Functions                                                                        ***/
    /**********************************************************************************************/

    /**
     *  @dev   Function to remove an addresses admin permissions.
     *  @param usr The address of the admin.
     */
    function deny(address usr) external;

    /**
     *  @dev   Function to give an address admin permissions.
     *  @param usr The address of the new admin.
     */
    function rely(address usr) external;

    /**
     * @dev   Function to set a new authority, permissioned to wards.
     * @param authority The address of the new authority.
     */
    function setAuthority(address authority) external;

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev   Function to freeze a specified market. Permissioned to the `hat` in the Chief.
     *  @param reserve The address of the market to freeze.
     */
    function freezeMarket(address reserve) external;

    /**
     *  @dev Function to freeze all markets. Permissioned to the `hat` in the Chief.
     */
    function freezeAllMarkets() external;

}
