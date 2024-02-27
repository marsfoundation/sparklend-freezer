// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IExecuteOnceSpell }    from "src/interfaces/IExecuteOnceSpell.sol";
import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_RemoveMultisig is IExecuteOnceSpell {

    address public immutable sparkLendFreezerMom;
    address public immutable multisig;

    bool public override executed;

    constructor(address sparkLendFreezerMom_, address multisig_) {
        sparkLendFreezerMom = sparkLendFreezerMom_;
        multisig            = multisig_;
    }

    function execute() external override {
        require(!executed, "RemoveMultisigSpell/already-executed");
        executed = true;
        ISparkLendFreezerMom(sparkLendFreezerMom).deny(multisig);
    }

}
