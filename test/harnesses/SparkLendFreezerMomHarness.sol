// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { SparkLendFreezerMom } from "src/SparkLendFreezerMom.sol";

contract SparkLendFreezerMomHarness is SparkLendFreezerMom {

    constructor(address poolConfigurator_, address pool_)
        SparkLendFreezerMom(poolConfigurator_, pool_) {}

    function isAuthorizedExternal(address src, bytes4 sig) public view returns (bool) {
        return super.isAuthorized(src, sig);
    }

}
