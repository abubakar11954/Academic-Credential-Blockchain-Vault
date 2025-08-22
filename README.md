# Academic Credential Blockchain Vault

## Overview

Academic Credential Blockchain Vault is a blockchain-based solution for issuing and verifying academic credentials on the Stacks blockchain. This project enables educational institutions to issue diplomas and transcripts as verifiable credentials with credential fingerprints written to the Stacks blockchain. Institutions sign credentials with approved keys, enabling instant authenticity verification.

## Features

- **Verifiable Credentials**: Issue diplomas and transcripts as blockchain-verifiable credentials
- **Credential Fingerprinting**: Write credential fingerprints to the Stacks blockchain for immutable records
- **Institutional Signing**: Institutions sign credentials with approved keys for authenticity
- **Instant Verification**: Enable instant authenticity checks for academic credentials
- **Secure Storage**: Leverage blockchain technology for tamper-proof credential storage

## Technology Stack

- **Blockchain**: Stacks (Bitcoin L2)
- **Smart Contracts**: Clarity
- **Testing Framework**: Vitest with Clarinet SDK
- **Development Tool**: Clarinet

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- [Clarinet](https://github.com/hirosystems/clarinet) (for smart contract development)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd academic-credential-blockchain-vault
```

2. Install dependencies:
```bash
npm install
```

## Project Structure

```
academic-credential-blockchain-vault/
├── contracts/           # Clarity smart contracts
├── tests/              # Test files for smart contracts
├── settings/           # Network configuration files
│   ├── Devnet.toml
│   ├── Testnet.toml
│   └── Mainnet.toml
├── .vscode/            # VS Code configuration
├── Clarinet.toml       # Clarinet project configuration
├── package.json        # Node.js dependencies and scripts
├── tsconfig.json       # TypeScript configuration
└── vitest.config.js    # Vitest testing configuration
```

## Development

### Running Tests

Run the test suite:
```bash
npm test
```

Run tests with coverage and cost reports:
```bash
npm run test:report
```

Watch mode for development:
```bash
npm run test:watch
```

### Smart Contract Development

This project uses Clarinet for smart contract development. Smart contracts should be placed in the `contracts/` directory with the `.clar` extension.

To add a new contract, update the `Clarinet.toml` file:
```toml
[contracts.your-contract-name]
path = "contracts/your-contract.clar"
epoch = "latest"
```

## Configuration

### Network Settings

Network configurations are stored in the `settings/` directory:
- `Devnet.toml` - Development network configuration
- `Testnet.toml` - Test network configuration
- `Mainnet.toml` - Main network configuration

### Clarinet Configuration

The `Clarinet.toml` file contains project configuration including:
- Project name and description
- Contract definitions
- Analysis settings with safety checks

## Testing

The project uses Vitest with the Clarinet SDK for testing smart contracts. The testing environment is configured to work seamlessly with Clarinet and the Simnet (simulated network).

Test files should be placed in the `tests/` directory and follow the naming convention `*.test.ts` or `*.spec.ts`.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Create a Pull Request

## License

ISC License - See package.json for details

## Support

For issues, questions, or contributions, please open an issue in the GitHub repository.
