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
     *  @dev    Returns a 0 or 1 depending on if the user has been added as an admin.
     *  @return relied The value of the user's admin status.
     */
    function wards(address user) external view returns (uint256 relied);

    /**********************************************************************************************/
    /*** Administrative Functions                                                               ***/
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

}
