# Cross-Chain Message Integrity

Security-focused Solidity implementation exploring the receiving-side trust boundary of cross-chain messaging.

The repository demonstrates how insufficient replay and nonce controls can allow an otherwise authenticated cross-chain message to be executed more than once, then implements and tests a hardened receiver designed to preserve message integrity under adversarial call sequences.

The focus is deliberately narrow: message authenticity alone is not sufficient. A receiver must also enforce uniqueness, ordering, and state integrity.

## Security Model

A cross-chain receiver accepts messages containing:

- `messageId`
- `sourceChainId`
- `sourceSender`
- `nonce`
- `payloadHash`

The receiver operates behind an authorized dispatcher and validates the expected source domain.

The security boundary addressed here begins after a message reaches the destination-side receiver. The implementation does not attempt to model bridge consensus, relayer infrastructure, validator sets, or source-chain finality.

The protected properties are:

1. A message identifier must not execute successfully more than once.
2. Successful messages from an authorized source must respect strict nonce ordering.
3. Rejected messages must not mutate protected receiver state.

## Vulnerability

`VulnerableReceiver` performs dispatcher and source validation but does not maintain replay state or enforce nonce progression.

As a result, an authenticated message can be submitted repeatedly and execute multiple times. Different message identifiers can also reuse the same nonce without rejection.

This represents a destination-side integrity failure: authentication of the message origin does not establish uniqueness of execution.

The unit tests reproduce both conditions explicitly.

## Hardened Receiver

`CrossChainReceiver` adds stateful integrity controls on top of the same dispatcher and source authorization boundary.

It maintains:

- processed-message state keyed by `messageId`
- source-specific nonce progression
- explicit replay rejection
- strict nonce validation

State changes occur only after all authorization and integrity checks succeed.

The implementation therefore separates two concerns that are often conflated:

**message authorization** — whether the message comes from an accepted transport and source

**message integrity** — whether that message is eligible to execute in the current destination state

## Adversarial Test Strategy

The test suite combines deterministic unit tests with stateful invariant testing.

### Unit Tests

Unit tests cover successful execution and targeted failure modes, including:

- unauthorized dispatcher calls
- invalid source chains
- invalid source senders
- replayed message identifiers
- reused nonces
- nonce jumps
- manipulated message data

`VulnerableReceiver.t.sol` demonstrates the replay and nonce-reuse behavior of the intentionally vulnerable implementation.

`CrossChainReceiver.t.sol` validates the corresponding controls in the hardened implementation.

### Stateful Invariant Testing

The invariant suite drives `CrossChainReceiver` through adversarial sequences generated through `MessageHandler`.

The handler attempts combinations of:

- valid messages
- replayed messages
- stale nonces
- future nonces
- invalid source chains
- invalid source senders
- unauthorized callers

The invariant suite continuously checks that:

```text
executionCount == successfulExecutions
```

and that successful execution preserves the expected nonce progression.

It also tracks attempted message identifiers to ensure that no message can successfully execute more than once and that `processedMessages` remains consistent with observed successful executions.

This is property-based security testing over generated call sequences. It is not presented as formal verification.

## Repository Structure

```text
cross-chain-message-integrity/
├── src/
│   ├── CrossChainReceiver.sol
│   └── VulnerableReceiver.sol
├── test/
│   ├── unit/
│   │   ├── CrossChainReceiver.t.sol
│   │   └── VulnerableReceiver.t.sol
│   └── invariant/
│       ├── MessageHandler.sol
│       └── MessageInvariant.t.sol
├── .github/
│   └── workflows/
│       └── test.yml
├── foundry.toml
└── README.md
```

## Test Results

The current suite contains 18 tests across unit and invariant test suites.

```text
18 passed
0 failed
0 skipped
```

Coverage of the production contracts:

| Contract | Lines | Statements | Branches | Functions |
| --- | ---: | ---: | ---: | ---: |
| `CrossChainReceiver.sol` | 100% | 100% | 100% | 100% |
| `VulnerableReceiver.sol` | 100% | 100% | 100% | 100% |

The invariant handler is test infrastructure and is intentionally evaluated separately from production-contract coverage.

## Running the Tests

Requirements:

- Foundry
- Solidity `^0.8.34`

Clone the repository including its submodules:

```bash
git clone --recurse-submodules https://github.com/BlockchainInes/cross-chain-message-integrity.git
cd cross-chain-message-integrity
```

Run the complete suite:

```bash
forge test
```

Run unit tests only:

```bash
forge test --match-path "test/unit/*"
```

Run the invariant suite:

```bash
forge test --match-path "test/invariant/*"
```

Generate coverage:

```bash
forge coverage
```

## Design Scope

This repository isolates one security boundary rather than implementing a complete cross-chain protocol.

It intentionally does not provide:

- bridge or relayer infrastructure
- validator or consensus logic
- source-chain finality verification
- token custody or bridging
- production transport adapters
- cross-chain proof verification

The objective is to make destination-side replay, ordering, and state-integrity properties explicit and independently testable.

## Security Considerations

The hardened receiver assumes that the configured dispatcher itself is trusted to represent the intended transport layer.

Source-chain and source-sender allowlisting establish the accepted message origin, while replay protection and nonce enforcement establish execution integrity at the receiver.

A production cross-chain system would require additional guarantees outside the scope of this repository, including transport authentication, finality assumptions, upgrade controls, operational key management, and protocol-specific verification mechanisms.

## Tooling

- Solidity `^0.8.34`
- Foundry
- Forge unit testing
- Forge stateful invariant testing
- GitHub Actions

## License

MIT
