// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_FreezeSingleAsset {

    address public sparkLendFreezer;
    address public reserve;

    constructor(address sparklendFreezer_, address reserve_) {
        sparkLendFreezer = sparklendFreezer_;
        reserve          = reserve_;
    }

    function freeze() external {
        ISparkLendFreezerMom(sparkLendFreezer).freezeMarket(reserve);
    }

}
