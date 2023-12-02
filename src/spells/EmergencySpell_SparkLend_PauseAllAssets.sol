// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezerMom } from "src/interfaces/ISparkLendFreezerMom.sol";

contract EmergencySpell_SparkLend_PauseAllAssets {

    address public immutable sparkLendFreezerMom;

    bool public executed;

    constructor(address sparklendFreezerMom_) {
        sparkLendFreezerMom = sparklendFreezerMom_;
    }

    function freeze() external {
        require(!executed, "PauseAllAssetsSpell/already-executed");
        executed = true;
        ISparkLendFreezerMom(sparkLendFreezerMom).pauseAllMarkets(true);
    }

}
