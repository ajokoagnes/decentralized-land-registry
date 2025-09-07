# Decentralized Land Registry

A blockchain-based land ownership and transfer system built on Bitcoin using Clarity smart contracts.

## Overview

The Decentralized Land Registry provides a trustless, transparent, and immutable system for managing land ownership records and facilitating secure property transfers. By leveraging Bitcoin's security and Clarity smart contracts, this system eliminates the need for traditional centralized land registries while ensuring complete transparency and authenticity of ownership records.

## Key Features

- **Immutable Ownership Records**: Land titles are stored on-chain, ensuring permanent and tamper-proof records
- **Digital Property Transfers**: Secure land transfers with cryptographic signatures and automated verification
- **Transparent History**: Complete audit trail of all ownership changes and property transactions
- **Decentralized Verification**: No single point of failure or control in the ownership verification process

## Smart Contracts

### 1. Land Title Registry (`land-title-registry.clar`)
- Manages ownership records and land metadata
- Stores property information including coordinates, size, and legal descriptions
- Handles initial land registration and ownership verification
- Maintains comprehensive property databases with searchable metadata

### 2. Transfer Authorization (`transfer-authorization.clar`)  
- Controls and logs land title transfers with digital signatures
- Validates transfer prerequisites and authorization requirements
- Manages escrow-like functionality for secure property transactions
- Records complete transfer history with timestamps and participant details

## Architecture

The system uses two complementary smart contracts:

- **Registry Contract**: Acts as the central database for all land records and ownership information
- **Transfer Contract**: Manages the transfer process, ensuring security and proper authorization

## Technical Specifications

- **Blockchain**: Bitcoin (Stacks Layer 2)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Comprehensive unit tests for all contract functions

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ajokoagnes/decentralized-land-registry.git
cd decentralized-land-registry
```

2. Install dependencies:
```bash
npm install
```

3. Run contract checks:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

## Usage

### Registering Land
Land registration requires providing property metadata including coordinates, legal description, and ownership proof.

### Transferring Property
Property transfers require authorization from current owner and validation of transfer conditions.

### Querying Ownership
Anyone can verify current ownership status and view property history through read-only functions.

## Security Considerations

- All transfers require cryptographic signatures from authorized parties
- Property metadata is validated before registration
- Transfer history is immutable and publicly auditable
- Smart contracts include comprehensive error handling and validation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run `clarinet check` and `clarinet test`
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions, issues, or contributions, please open an issue on GitHub or contact the development team.

## Roadmap

- [ ] Integration with mapping services
- [ ] Mobile application development
- [ ] Multi-signature support for joint ownership
- [ ] Integration with legal document systems
- [ ] Advanced search and filtering capabilities
