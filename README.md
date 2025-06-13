# Invoice Financing Protocol with Chainlink

[![Built with Chainlink](https://img.shields.io/badge/Built%20with-Chainlink-375BD2)](https://chain.link/)
[![Hardhat](https://img.shields.io/badge/Hardhat-v2.22.0-FFD83D)](https://hardhat.org/)

A decentralized invoice financing platform where businesses can tokenize unpaid invoices as NFTs, with payment verification powered by Chainlink.

## Key Features

| Feature | Description |
|---------|-------------|
| **Invoice NFTs** | Tokenize real-world invoices as tradable ERC-721 assets |
| **Chainlink Functions** | Verify off-chain payments via bank/processor APIs |
| **Automated Settlements** | Chainlink Automation enforces due dates and penalties |
| **Price Oracle** | Accurate USDC/USD conversions via Chainlink Data Feeds |
| **Dispute Resolution** | VRF-selected auditors for contested invoices |

## Protocol Workflow

```mermaid
flowchart TD
    A[Seller] -->|1. Mint NFT| B(InvoiceNFT Contract)
    B -->|2. List| C[Marketplace]
    D[Buyer] -->|3. Buy with USDC| C
    C -->|4. Escrow| E[USDC Pool]
    B -->|5. Verify| F[Chainlink Functions]
    F -->|6. Bank API| G{Payment Confirmed?}
    G -->|Yes| H[Release to Seller]
    G -->|No| I[Refund Buyer]
```

# Installation
```bash
git clone https://github.com/your-repo/invoice-financing.git
cd invoice-financing
npm install
```

# Configuration
```bash
SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY"
PRIVATE_KEY="0xYOUR_KEY"
CHAINLINK_SUBSCRIPTION_ID=123
```

# Testing
```bash
npx hardhat test
```

# Architecture
contracts/
├── InvoiceNFT.sol           # Main logic (NFT minting/verification)
├── PriceOracle.sol          # USDC/USD conversions
├── Escrow.sol               # Payment escrow
└── interfaces/
    ├── IUSDC.sol            # USDC token interface
    └── IVRF.sol             # VRF consumer
