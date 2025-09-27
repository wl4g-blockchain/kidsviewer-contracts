# KidsViewer Starknet Contracts

This directory contains the Cairo implementations of the KidsViewer smart contracts, translated from the original Solidity versions using modern Cairo syntax.

## Contract Overview

### 1. KidsViewerVault.cairo
**Purpose**: Vault contract for parent deposits and reward distribution management
**Key Features**:
- Parent registration and child authorization
- Token deposit/withdrawal functionality
- Daily reward limit enforcement per child
- Reward distribution to children
- Emergency pause/unpause functionality

**Main Functions**:
- `register_parent()` - Register a parent account
- `authorize_child()` - Authorize a child for a parent
- `deposit()` - Parents deposit tokens to vault
- `withdraw()` - Parents withdraw tokens from vault
- `distribute_reward()` - Distribute rewards to children
- `set_daily_reward_limit()` - Set daily reward limits for children

### 2. KidsViewerPiggyBank.cairo
**Purpose**: Piggy bank contract for children's rewards and DeFi investments
**Key Features**:
- Child reward management
- Withdrawal request system (requires parent approval)
- DeFi investment functionality with AAVE integration
- Parent approval system for investments
- Earnings tracking and calculation

**Main Functions**:
- `receive_reward()` - Receive rewards from vault
- `request_withdrawal()` - Children request withdrawals
- `approve_withdrawal()` - Parents approve withdrawals
- `invest_in_aave()` - Children invest in AAVE products
- `recover_all_investments()` - Parents recover investments
- `set_parent_approval()` - Set parent approval for children

### 3. KRC.cairo
**Purpose**: Platform utility token (Knowledge Reward Coin)
**Key Features**:
- ERC20 token functionality
- Fee discount system based on holdings
- Yield boost system
- Governance voting system
- Staking functionality with rewards
- Privilege access management

**Main Functions**:
- `mint()` - Mint new tokens (owner only)
- `burn()` - Burn tokens
- `update_fee_discount()` - Update fee discount based on holdings
- `update_yield_boost()` - Update yield boost based on holdings
- `start_staking()` - Start staking KRC tokens
- `end_staking()` - End staking and claim rewards
- `create_proposal()` - Create governance proposals
- `vote()` - Vote on proposals

## Modern Cairo Syntax Features

### 1. Interface Definition
```cairo
#[starknet::interface]
pub trait IContractName<TContractState> {
    fn function_name(self: @TContractState) -> ReturnType;
    fn function_name(ref self: TContractState, param: Type);
}
```

### 2. Contract Structure
```cairo
#[starknet::contract]
pub mod ContractName {
    use super::{ContractState, Storage, Event, ...};
    
    #[abi(embed_v0)]
    impl ContractImpl of IContractName<ContractState> {
        // Implementation
    }
}
```

### 3. Events
```cairo
#[starknet::event]
#[derive(Drop, starknet::Event)]
pub enum Event {
    EventName: EventName,
}

#[derive(Drop, starknet::Event)]
pub struct EventName {
    pub field: Type,
}
```

### 4. Storage
```cairo
#[starknet::storage]
pub struct Storage {
    pub field: Map<Key, Value>;
    pub simple_field: Type;
}
```

### 5. Constructor
```cairo
#[starknet::constructor]
fn constructor(ref self: ContractState) {
    // Constructor logic
}
```

## Key Differences from Solidity Version

1. **Modern Syntax**: Uses latest Cairo syntax with `#[starknet::interface]`, `#[starknet::contract]`, etc.
2. **Data Types**: Uses `ContractAddress`, `Uint256`, `felt252` instead of `felt`
3. **Storage**: Uses `Map<Key, Value>` for mappings with explicit read/write operations
4. **Events**: Uses `#[starknet::event]` with proper struct definitions
5. **Functions**: Uses `ref self: TContractState` for state modification
6. **Error Handling**: Uses `assert_*` functions for error handling
7. **Interface Pattern**: Implements proper interface pattern with trait definitions

## Usage Notes

1. **Deployment**: Deploy contracts in the following order:
   - KRC token
   - KidsViewerVault
   - KidsViewerPiggyBank (with vault address)

2. **Configuration**: Set up supported tokens and initial parameters after deployment

3. **Integration**: The contracts are designed to work together as a complete system for managing children's rewards and investments

## Security Considerations

- All contracts include proper access controls
- Input validation is performed on all external functions
- Emergency pause functionality is available for critical functions
- Modern Cairo syntax provides better type safety

## Development Status

These contracts are translated from the original Solidity versions using modern Cairo syntax and maintain the same functionality. They should be thoroughly tested before deployment to mainnet.

## Dependencies

- Starknet standard library
- Modern Cairo syntax (Cairo 2.0+)
- AAVE integration (for DeFi functionality)
