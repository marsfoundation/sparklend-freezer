// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IExecuteOnceSpell }    from "src/interfaces/IExecuteOnceSpell.sol";
import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_FreezeAllAssets is IExecuteOnceSpell {

    address public immutable sparkLendFreezerMom;

    bool public override executed;

    constructor(address sparkLendFreezerMom_) {
        sparkLendFreezerMom = sparkLendFreezerMom_;
    }

    function execute() external override {
        require(!executed, "FreezeAllAssetsSpell/already-executed");
        executed = true;
        ISparkLendFreezerMom(sparkLendFreezerMom).freezeAllMarkets(true);
    }

}
