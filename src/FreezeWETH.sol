// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { ISparkLendFreezer } from "src/interfaces/ISparkLendFreezer.sol";

contract FreezeWETH {

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public sparkLendFreezer;

    constructor(address sparklendFreezer_) {
        sparkLendFreezer = sparklendFreezer_;
    }

    function freeze() external {
        ISparkLendFreezer(sparkLendFreezer).freezeMarket(WETH);
    }

}
