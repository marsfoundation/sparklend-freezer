// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IExecuteOnceSpell }    from "src/interfaces/IExecuteOnceSpell.sol";
import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_PauseAllAssets is IExecuteOnceSpell {

    address public immutable sparkLendFreezerMom;

    bool public override executed;

    constructor(address sparklendFreezerMom_) {
        sparkLendFreezerMom = sparklendFreezerMom_;
    }

    function execute() external override {
        require(!executed, "PauseAllAssetsSpell/already-executed");
        executed = true;
        ISparkLendFreezerMom(sparkLendFreezerMom).pauseAllMarkets(true);
    }

}
