# What is Dracula Protocol?

Dracula Protocol is a universal DeFi adapter that aggregates interest earning strategies, known as yield farming, into a singular protocol. Dracula Protocol aims to consolidate various aspects of DeFi into one platform and is managed through a Distributed Autonomous Organization (DAO), in which voting rights are quantified by $DRC ownership.

# How does it work?

Dracula Protocol allows users to deposit their assets through its interface, which are then deposited into underlying platforms to earn interest. Dracula Protocol adds a layer of security when yield farming, while also consolidating all steps necessary to earn interest into one protocol.

# Dracula Protocol contracts

## Core contracts

__MasterVampire__ [0xB58E80f655F451f4AD2278a7D806C475AcCdB8bd](https://etherscan.io/address/0xB58E80f655F451f4AD2278a7D806C475AcCdB8bd) implements the core logic behind Dracula Protocol.

__DraculaToken__ [0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8](https://etherscan.io/address/0xb78b3320493a4efaa1028130c5ba26f0b6085ef8) ERC20-interface compliant token with minter set to __MasterVampire__ and vote-delegating functionality.

__DrainController__ [0x4852a488F15AE544C75FED466908A2D1559EBAfa](https://etherscan.io/address/0x4852a488F15AE544C75FED466908A2D1559EBAfa)

__DrainDistributor__ [0x62440aE6a5b861D01b0104D6ED77DbEDA29c4dc8](https://etherscan.io/address/0x62440aE6a5b861D01b0104D6ED77DbEDA29c4dc8)

__DRCRewardPool__ [0xcAABb5e44868F720924Aa2c8c4809d4F236Ed7Ee](https://etherscan.io/address/0xcAABb5e44868F720924Aa2c8c4809d4F236Ed7Ee) DRC staking pool.

__LPRewardPool__ [0xcA329C19396DfB92F570FD19E6F468AF87c9a9c1](https://etherscan.io/address/0xcA329C19396DfB92F570FD19E6F468AF87c9a9c1) DRC/ETH UNI-LP staking pool.

__IVampireAdapter__ interface that allows __Master Vampire__ to uniformly communicate with various target pools, effectively shadowing all the differences between them. Every victim's adapter smart-contract implements this interface. The interface also contains several informational methods that will be used in Governance for automatic reward redistribution.

__VampireAdapter__ is a helper library, that makes delegate calls from __MasterVampire__ to target adapters.

## Adapters
There are several adapters to the most popular farming contracts. Every one of them is a separate contract that implements the __IVampireAdapter__ interface.

__DODOAdapter__ [0x680276CF3Ea6C52F0fCa4BA216C3353fe387EBdE](https://etherscan.io/address/0x680276CF3Ea6C52F0fCa4BA216C3353fe387EBdE)

__LuaAdapter__ [0x8dF2844f3f2e3297d57E2A9EE38AB3f7AF652e03](https://etherscan.io/address/0x8dF2844f3f2e3297d57E2A9EE38AB3f7AF652e03)

__PickleAdapter__ [0x8432BF53c68aed9E703ABCd78Be3810478F1eE36](https://etherscan.io/address/0x8432BF53c68aed9E703ABCd78Be3810478F1eE36)

__SushiAdapter__ [0x750bA66B58708C7C1F396844F41dc84b0092F427](https://etherscan.io/address/0x750bA66B58708C7C1F396844F41dc84b0092F427)

__TruFiAdapter__ [0xe26Ab391A2bA6D9A5399aE412727Dd197414cFA1](https://etherscan.io/address/0xe26Ab391A2bA6D9A5399aE412727Dd197414cFA1)


# Local Development

The following assumes the use of `node@>=14`.

## Environment

Copy `.env.example` to `.env` and update variables

## Install Dependencies

`npm install`

## Compile Contracts

`npm run build`

## Run Tests

`npm run test`
