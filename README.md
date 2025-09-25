# Kliver OnChain Sessions Registry

A Cairo smart contract for Starknet that manages AI interaction sessions, step completion tracking, and scoring validation for the Kliver platform.

## Overview

The Kliver Sessions Registry is a decentralized solution that tracks user interactions with AI challenges, manages step completion status, and provides a robust scoring system. The contract ensures data integrity through cryptographic hashing and implements business logic to prevent invalid session progressions.

## Features

### 🤖 **AI Interaction Management**
- Register individual AI interactions with scoring (0-100)
- Sequential interaction validation per step
- Maximum 15 interactions per step
- Cryptographic hash generation for interaction integrity

### 📊 **Step Completion System**
- **Success Completion**: Complete steps successfully when all criteria are met
- **Failed Completion**: Mark steps as failed while preserving interaction data
- **Session Protection**: Prevent successful completions after any step failure in the same session
- **Marketplace Integration**: Generate verifiable hashes for completed steps

### 📈 **Statistics & Analytics**
- Individual user statistics tracking
- Global contract statistics
- Real-time activity monitoring
- Score accumulation and completion counters

### 🔐 **Security & Access Control**
- Owner-based access control
- Contract pause/unpause functionality
- Input validation for all parameters
- Reentrancy protection

### 🔍 **Query & Pagination**
- Retrieve interactions with pagination support
- Check step completion status
- Session failure state validation
- Efficient data retrieval for large datasets

## Contract Architecture

### Core Data Structures

```cairo
/// Individual AI interaction record
struct Interaction {
    message_hash: felt252,    // Hash of the message content
    scoring: u32,            // Score (0-100)
    timestamp: u64,          // When the interaction occurred
}

/// Completed step information
struct CompletedStep {
    interactions_hash: felt252,     // Combined hash of all interactions
    max_score: u32,                // Highest score in the step
    total_interactions: u32,       // Number of interactions
    player: ContractAddress,       // Who completed the step
    timestamp: u64,               // Completion timestamp
    status: StepCompletionStatus, // Success or Failed
}

/// User activity statistics
struct UserStats {
    total_interactions: u32,
    total_completed_steps: u32,
    total_score: u64,
    last_activity: u64,
}
```

### Step Completion States

```cairo
enum StepCompletionStatus {
    Success,  // Step completed successfully
    Failed,   // Step completed with failure
}
```

## Key Business Rules

### 🚦 **Session Flow Control**
1. **Normal Flow**: Users can complete steps successfully in sequence
2. **Failure Handling**: Once a step fails in a session, no subsequent steps can be completed successfully
3. **Session Isolation**: Failures in one session don't affect other sessions
4. **Multiple Failures**: Multiple steps can fail within the same session

### 📋 **Validation Rules**
- **Scoring**: Must be between 0-100 (inclusive)
- **Interactions**: Sequential positioning (1, 2, 3, ...)
- **Step Limits**: Maximum 15 interactions per step
- **Completion**: Steps must have at least 1 interaction to be completed

## API Reference

### Core Functions

#### `register_interaction`
Register a new AI interaction within a step.

```cairo
fn register_interaction(
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252,
    interaction_pos: u32,    // Position in sequence (1, 2, 3, ...)
    message_hash: felt252,   // Hash of the interaction content
    scoring: u32            // Score 0-100
) -> bool
```

#### `complete_step_success`
Complete a step successfully (if session has no failures).

```cairo
fn complete_step_success(
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252
) -> felt252  // Returns interaction hash
```

#### `complete_step_failed`
Mark a step as failed (always allowed).

```cairo
fn complete_step_failed(
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252
) -> felt252  // Returns interaction hash
```

### Query Functions

#### `get_step_interactions`
Retrieve all interactions for a specific step.

```cairo
fn get_step_interactions(
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252
) -> Array<Interaction>
```

#### `get_step_interactions_paginated`
Retrieve interactions with pagination support.

```cairo
fn get_step_interactions_paginated(
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252,
    start: u32,    // Starting index
    limit: u32     // Maximum items (≤100)
) -> Array<Interaction>
```

#### `session_has_failed_step`
Check if a session has any failed steps.

```cairo
fn session_has_failed_step(
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252
) -> bool
```

#### `get_user_stats`
Get comprehensive user statistics.

```cairo
fn get_user_stats(user_id: felt252) -> UserStats
```

### Administrative Functions

#### `pause` / `unpause`
Control contract operations (owner only).

#### `transfer_ownership`
Transfer contract ownership (owner only).

```cairo
fn transfer_ownership(new_owner: ContractAddress)
```

## Development Setup

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (Cairo package manager)
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) (Testing framework)
- Cairo 2.8.2+

### Installation

1. Clone the repository:
```bash
git clone https://github.com/germankuber/KliverOnChain.git
cd KliverOnChain
```

2. Install dependencies:
```bash
scarb build
```

### Running Tests

Execute the comprehensive test suite:

```bash
# Run all tests
scarb test

# Run specific test categories
snforge test test_register_interaction
snforge test test_complete_step
snforge test test_step_completion_status
```

### Test Coverage

The contract includes 68 comprehensive tests covering:
- ✅ Interaction registration and validation
- ✅ Step completion (success and failure scenarios)
- ✅ Session state management
- ✅ Pagination and data retrieval
- ✅ Security and access control
- ✅ Edge cases and error conditions
- ✅ Statistics accuracy
- ✅ Business rule enforcement

## Usage Examples

### Basic Interaction Flow

```cairo
// 1. Register interactions
contract.register_interaction(user_id, challenge_id, session_id, step_id, 1, hash1, 85);
contract.register_interaction(user_id, challenge_id, session_id, step_id, 2, hash2, 92);

// 2. Complete step successfully
let interaction_hash = contract.complete_step_success(user_id, challenge_id, session_id, step_id);

// 3. Check completion status
let is_completed = contract.is_step_completed(user_id, challenge_id, session_id, step_id);
let has_failures = contract.session_has_failed_step(user_id, challenge_id, session_id);
```

### Failure Handling

```cairo
// 1. Complete a step as failed
contract.complete_step_failed(user_id, challenge_id, session_id, step1);

// 2. This will now fail - session has a failed step
contract.complete_step_success(user_id, challenge_id, session_id, step2); // ❌ Reverts

// 3. But this will work - can still fail additional steps
contract.complete_step_failed(user_id, challenge_id, session_id, step2); // ✅ Works
```

## Constants & Limits

| Parameter | Value | Description |
|-----------|-------|-------------|
| `MAX_SCORE` | 100 | Maximum scoring value |
| `MIN_SCORE` | 0 | Minimum scoring value |
| `MAX_INTERACTIONS_PER_STEP` | 15 | Maximum interactions per step |
| `MAX_PAGINATION_LIMIT` | 100 | Maximum items per page |

## Events

The contract emits the following events:

### `InteractionRegistered`
```cairo
struct InteractionRegistered {
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252,
    interaction_pos: u32,
    message_hash: felt252,
    scoring: u32,
    timestamp: u64,
}
```

### `StepCompleted`
```cairo
struct StepCompleted {
    user_id: felt252,
    challenge_id: felt252,
    session_id: felt252,
    step_id: felt252,
    interactions_hash: felt252,
    max_score: u32,
    total_interactions: u32,
    player: ContractAddress,
    timestamp: u64,
}
```

## Security Considerations

### Input Validation
- All function parameters are validated for zero values
- Scoring is bounded between 0-100
- Interaction positions must be sequential
- Pagination limits are enforced

### Access Control
- Owner-only functions for administration
- Pause mechanism for emergency stops
- Ownership transfer capability

### State Protection
- Steps cannot be completed twice
- Session failure state is immutable
- Interaction sequence integrity is enforced

## Gas Optimization

The contract implements several gas optimization strategies:
- Efficient storage layout using Cairo's `Map` type
- Minimal state reads through careful function design
- Optimized loops using `!= condition + 1` pattern
- Event emission only for state changes

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Write comprehensive tests for new features
- Follow Cairo naming conventions
- Document all public functions
- Maintain gas efficiency
- Ensure backward compatibility

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

- **Developer**: German Kuber
- **GitHub**: [@germankuber](https://github.com/germankuber)
- **Project**: [KliverOnChain](https://github.com/germankuber/KliverOnChain)

---

**Built with ❤️ using Cairo and Starknet**