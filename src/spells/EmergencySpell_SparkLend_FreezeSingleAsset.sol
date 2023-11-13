// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_FreezeSingleAsset {

    address public immutable sparkLendFreezerMom;
    address public immutable reserve;

    constructor(address sparklendFreezerMom_, address reserve_) {
        sparkLendFreezerMom = sparklendFreezerMom_;
        reserve             = reserve_;
    }

    function freeze() external {
        ISparkLendFreezerMom(sparkLendFreezerMom).freezeMarket(reserve);
    }

}
