# SparkLend Freezer

![Foundry CI](https://github.com/marsfoundation/sparklend-freezer/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/marsfoundation/sparklend-freezer/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repo contains five contracts:

### `src/SparkLendFreezerMom.sol`
A contract that will have `RISK_ADMIN_ROLE` & `EMERGENCY_ADMIN_ROLE` in SparkLend, and has four functions:
- `freezeAllMarkets`: Freezes all markets in SparkLend, callable by the `hat` in the Chief, an authorized contract (ward) or by the PauseProxy in MakerDAO.
- `freezeMarket`: Freezes a single market in SparkLend, callable by the `hat` in the Chief, an authorized contract (ward) or by the PauseProxy in MakerDAO.
- `pauseAllMarkets`: Pauses all markets in SparkLend, callable by the `hat` in the Chief, an authorized contract (ward) or by the PauseProxy in MakerDAO.
- `pauseMarket`: Pauses a single market in SparkLend, callable by the `hat` in the Chief, an authorized contract (ward) or by the PauseProxy in MakerDAO.

### `src/spells/EmergencySpell_SparkLend_FreezeAllAssets.sol`
A spell that can be set as the `hat` in the Chief to freeze all markets in SparkLend by calling `freezeAllMarkets(true)` in `SparkLendFreezerMom`.

### `src/spells/EmergencySpell_SparkLend_FreezeSingleAsset.sol`
A spell that can be set as the `hat` in the Chief to freeze a specific market in SparkLend by calling `freezeMarket(reserve, true)` in `SparkLendFreezerMom`. A separate spell is needed for each market, with the reserve being declared in the constructor.

### `src/spells/EmergencySpell_SparkLend_PauseAllAssets.sol`
A spell that can be set as the `hat` in the Chief to pauses all markets in SparkLend by calling `pauseAllMarkets(true)` in `SparkLendFreezerMom`.

### `src/spells/EmergencySpell_SparkLend_PauseSingleAsset.sol`
A spell that can be set as the `hat` in the Chief to pause a specific market in SparkLend by calling `pauseMarket(reserve, true)` in `SparkLendFreezerMom`. A separate spell is needed for each market, with the reserve being declared in the constructor.

## Testing
To run the tests, run `forge test`.

***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP*
