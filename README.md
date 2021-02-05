# Dracula Protocol contracts

## Core contracts

__MasterVampire__ [TBD](https://etherscan.io/address/TBD) implements the core logic behind Dracula Protocol.

__DraculaToken__ [0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8](https://etherscan.io/address/0xb78b3320493a4efaa1028130c5ba26f0b6085ef8) ERC20-interface compliant token with minter set to __Master Vampire__ and vote-delegating functionality.

__DrainController__ [TBD](https://etherscan.io/address/TBD)

__DrainDistributor__ [TBD](https://etherscan.io/address/TBD)

__RewardPool__ [TBD](https://etherscan.io/address/TBD)

__IVampireAdapter__ interface that allows __Master Vampire__ to uniformly communicate with various target pools, effectively shadowing all the differences between them. Every victim's adapter smart-contract implements this interface. The interface also contains several informational methods that will be used in Governance for automatic reward redistribution.

__VampireAdapter__ is a helper library, that makes delegate calls from __Mater Vampire__ to target adapters.

## Adapters
There are several adapters to the most popular farming contracts. Every one of them is a separate contract that implements the __IVampireAdapter__ interface.

__SushiAdapter__ [TBD](https://etherscan.io/address/TBD)

__LuaAdapter__ [TBD](https://etherscan.io/address/TBD)

__UniswapAdapter__ [TBD](https://etherscan.io/address/TBD)

__PickleAdapter__ [TBD](https://etherscan.io/address/TBD)

__YfvAdapter__ [TBD](https://etherscan.io/address/TBD)

__DODOAdapter__ [TBD](https://etherscan.io/address/TBD)

__SashimiAdapter__ [TBD](https://etherscan.io/address/TBD)


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