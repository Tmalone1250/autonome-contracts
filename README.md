# Autonome Smart Contracts (`autonome-contracts/`)

The **Autonome Smart Contracts** workspace contains the Solidity smart contracts, Foundry deployment scripts, and unit tests governing task escrow, decentralized compute settlement, tokenomics distribution, and gasless meta-transactions on BOT Chain (Bohr Testnet / Mainnet).

---

## Deployed Contract Addresses (Bohr Testnet - Chain ID 968)

| Contract | Address | Explorer Link |
| :--- | :--- | :--- |
| **`AutonomeSettlementEscrow`** | `0x5b30dB9F00F9fa644a13117D5b31844223e3Fb4E` | [View on Bohr Scan](https://scan.bohr.life/address/0x5b30dB9F00F9fa644a13117D5b31844223e3Fb4E) |
| **`AutonomeToken` (ATMA)** | `0xd29dE89D308b3F1eAcF3c36f821842F8F6f3f840` | [View on Bohr Scan](https://scan.bohr.life/address/0xd29dE89D308b3F1eAcF3c36f821842F8F6f3f840) |
| **SimpleAccountFactory (ERC-4337)** | `0xBC88d6012b3bf8426C2851d3798cEB5257658332` | Counterfactual Vault Factory |
| **EntryPoint (ERC-4337)** | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | Canonical ERC-4337 EntryPoint |

---

## Smart Contract Architecture

### 1. `AutonomeSettlementEscrow.sol`
Serves as the automated clearinghouse for intent execution fees. It locks user task fees (in ATMA tokens) and programmatically disburses funds upon cryptographic validation by the Orchestrator.

#### Fee Breakdown Model (Basis Points)
Total Fee Allocation = 10,000 bps (100%):
- **70% (`7000 bps`) - Sub-Agent Developer**: Disbursed directly to the developer wallet of the AI agent executing the user intent.
- **15% (`1500 bps`) - DePIN Compute Node Operator**: Transferred to the Node Operator's counterfactual ERC-4337 Smart Account Vault.
- **10% (`1000 bps`) - POL Treasury**: Allocated to the Protocol-Owned Liquidity (POL) treasury on BDEX V3.
- **5% (`500 bps`) - Native Deflationary Burn**: Permanently burned from the total supply of ATMA via `AutonomeToken.burn()`.

```
                  ┌──────────────────────────────┐
                  │ Task Fee Deposited (ATMA)    │
                  └──────────────┬───────────────┘
                                 │
                    [ settleTask() Triggered ]
                                 │
         ┌───────────────────────┼───────────────────────┐
         │ (70%)                 │ (15%)                 │ (10%)                 │ (5%)
         ▼                       ▼                       ▼                       ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Sub-Agent        │    │ Compute Node     │    │ BDEX POL         │    │ Permanent        │
│ Developer        │    │ Operator Vault   │    │ Treasury         │    │ Token Burn       │
└──────────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
```

#### Key Functions
- `depositIntent(bytes32 taskId, uint256 amount)`: Locks `amount` of ATMA tokens for a specific task using standard ERC-20 allowance.
- `depositIntentWithPermit(...)`: Gasless escrow deposit utilizing ERC-2612 signature permit.
- `settleTask(bytes32 taskId, address subAgent, address computeNode)`: Callable strictly by the authorized `validator` (Orchestrator). Triggers the 70/15/10/5 fee split and token burn.
- `refundTask(bytes32 taskId)`: Callable by the `validator` to return escrowed funds to the user if execution fails.

---

### 2. `AutonomeToken.sol` (ATMA)
`AutonomeToken` is the utility, reward, and governance token of the Autonome ecosystem.
- **Standards Implemented**: ERC-20, ERC-20 Burnable, ERC-20 Permit (EIP-2612 for gasless approvals), Ownable.
- **Decimals**: 18
- **Minting**: Initial supply minted to deployer upon contract deployment; owner can mint additional rewards for network growth.

---

## Directory Structure

```
autonome-contracts/
├── src/
│   ├── AutonomeSettlementEscrow.sol   # Settlement & escrow logic
│   └── AutonomeToken.sol              # ATMA ERC-20 utility token
├── script/
│   ├── DeployEscrow.s.sol             # Foundry deployment script for Escrow & ATMA
│   └── AutonomeToken.s.sol            # Standalone token deployment script
├── test/                              # Foundry Forge unit tests
├── foundry.toml                       # Foundry configuration file
├── remappings.txt                     # Dependency path remappings
└── .env                               # Private key & RPC configuration
```

---

## Setup & Deployment Guide

### Prerequisites
- **Foundry** (`forge`, `cast`, `anvil`): Installed via `foundryup`.

### Build & Test Commands

```bash
# Clone and navigate to directory
cd autonome-contracts

# Install dependencies via Forge
forge install

# Build contracts
forge build

# Run unit tests
forge test -vvv
```

### Environment Configuration (`.env`)

```ini
PRIVATE_KEY=0x...
BOHR_RPC_URL=https://rpc.bohr.life
CHAIN_ID=968
POL_TREASURY_ADDRESS=0x...
VALIDATOR_ADDRESS=0x...
```

### Deployment to Bohr Testnet

```bash
# Load environment variables
source .env

# Deploy using Foundry Script
forge script script/DeployEscrow.s.sol:DeployEscrowScript \
  --rpc-url $BOHR_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --evm-version shanghai
```

> **Note on EVM Target**: When compiling or deploying to BOT Chain / Bohr, ensure `--evm-version shanghai` or `evm_version = "shanghai"` in `foundry.toml` is used to maintain compatibility with standard EVM opcodes.
