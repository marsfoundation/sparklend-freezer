# SparkLend Freezer

![Foundry CI](https://github.com/marsfoundation/sparklend-freezer/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/marsfoundation/sparklend-freezer/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repo contains five contracts:

### `src/SparkLendFreezerMom.sol`
A contract that will have `RISK_ADMIN_ROLE` (can freeze markets) & `EMERGENCY_ADMIN_ROLE` (can pause markets) in SparkLend, and has four functions:
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

## Execution Flow Diagrams

The below diagrams outlines the execution flow of freezing a single market in SparkLend for both token-based governance in MakerDAO and the emergency multisig, which will be added as a `ward` in the FreezerMom.
The same execution flow applies to all actions, this is a single example.

### Spell Execution Flow

For token-based governance to execute a freeze/pause in SparkLend, a pre-deployed spell must be voted to be the `hat` by MKR holders. Once that is done, any account can call `execute()` on the spell, which will call the FreezerMom. The FreezerMom will a permissioned account in SparkLend with the ability to both freeze and pause.

![Call Routing - Spell](https://github.com/marsfoundation/sparklend-freezer/assets/44272939/8ec26367-099f-476d-986e-b61403747172)

### Multisig Execution Flow

For the multisig to execute a freeze/pause in SparkLend, the quorum must be reached and then the desired function can be called directly on the FreezerMom. The FreezerMom will a permissioned account in SparkLend with the ability to both freeze and pause.

![Call Routing - Multisig 2](https://github.com/marsfoundation/sparklend-freezer/assets/44272939/136a9dbf-bd95-436b-a789-e4d5ddcb3cde)

## Testing

To run the tests, run `forge test`.

***
*The IP in this repository was assigned to Mars SPC Limited in respect of the MarsOne SP*
