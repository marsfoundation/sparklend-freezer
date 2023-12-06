// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

interface IExecuteOnceSpell {

    /**
     *  @dev Returns true if the spell has been executed.
     */
    function executed() external view returns (bool);

    /**
     *  @dev Executes the spell. Can only be called once.
     */
    function execute() external;

}
