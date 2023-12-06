// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IExecuteOnceSpell }    from "src/interfaces/IExecuteOnceSpell.sol";
import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_PauseSingleAsset is IExecuteOnceSpell {

    address public immutable sparkLendFreezerMom;
    address public immutable reserve;

    bool public override executed;

    constructor(address sparkLendFreezerMom_, address reserve_) {
        sparkLendFreezerMom = sparkLendFreezerMom_;
        reserve             = reserve_;
    }

    function execute() external override {
        require(!executed, "PauseSingleAssetSpell/already-executed");
        executed = true;
        ISparkLendFreezerMom(sparkLendFreezerMom).pauseMarket(reserve, true);
    }

}
