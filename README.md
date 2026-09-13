# 📜 Autonome Smart Contracts

This repository contains the core foundational smart contracts for the **Autonome Decentralized AI Protocol**, built and deployed on the BOT Chain ecosystem.

The contracts are built using [Foundry](https://getfoundry.sh/) and are specifically designed to handle verifiable execution escrows and network operator rewards.

---

## 🏗️ Contracts Architecture

### 1. `AutonomeToken.sol` (ATMA)
The native utility and governance ERC-20 token for the Autonome network.
- **Name:** Autonome Token
- **Symbol:** ATMA
- **Usage:** Used exclusively to fund the compute escrows for executing AI workloads. Sub-Agents pre-fund tasks with ATMA, and Compute Nodes claim ATMA as a reward for successful execution.

### 2. `AutonomeSettlementEscrow.sol`
The verifiable execution ledger and escrow contract.
- **Deposit Task:** Sub-Agents call `depositTask` to securely lock ATMA tokens with a specific task hash and domain identifier.
- **Submit Proof:** Compute Workers call `submitProof` to provide cryptographic evidence of execution (a `Keccak256` hash of the task prompt, inference output, and the node's private signature).
- **Settlement:** If the execution is verified and the node is whitelisted, the ATMA escrow is immediately released directly into the Node Operator's Smart Account Vault.

### 3. ERC-4337 Smart Accounts (Account Abstraction)
While the core logic of `EntryPoint` and `SimpleAccountFactory` are natively deployed to the BOT Chain Bohr Testnet, these contracts are designed to seamlessly interoperate with ERC-4337 vaults to isolate and secure Node Operator earnings.

---

## 🚀 Development & Deployment

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- A Web3 Wallet funded with Bohr Testnet `tBOT` (Chain ID 968)

### Installation
```bash
# Install dependencies
forge install
```

### Build & Test
```bash
# Compile contracts
forge build

# Run unit tests
forge test
```

### Deployment to Bohr Testnet
To deploy updates to the `AutonomeToken` or `AutonomeSettlementEscrow`:

1. Configure your `.env` with a `PRIVATE_KEY`.
2. Run the deployment scripts targeting the Bohr Testnet:

```bash
forge script script/AutonomeToken.s.sol:AutonomeTokenScript \
  --rpc-url https://rpc.bohr.life \
  --broadcast \
  --legacy
```

---

## 🌐 Network Details (Bohr Testnet)
- **Chain ID:** 968
- **RPC URL:** `https://rpc.bohr.life`
- **Block Explorer:** `https://scan.bohr.life`

*Built for the BOT Chain Ecosystem.*
