// // SPDX-License-Identifier: MIT

// use core::integer::u256;
// use starknet::event::EventEmitter;
// use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

// // Interface definition for KRC Staking
// #[starknet::interface]
// pub trait IKRCStaking<CS> {
//     // Staking functions
//     fn start_staking(ref self: CS, amount: u256, duration: u64);
//     fn end_staking(ref self: CS);
//     fn emergency_withdraw(ref self: CS);

//     // View functions
//     fn get_user_staking_info(self: @CS, user: ContractAddress) -> StakingInfo;
//     fn get_total_staked(self: @CS) -> u256;
//     fn get_total_staking_rewards(self: @CS) -> u256;
//     fn get_user_staking_rewards(self: @CS, user: ContractAddress) -> u256;

//     // Configuration
//     fn set_krc_contract(ref self: CS, krc_contract: ContractAddress);
//     fn get_krc_contract(self: @CS) -> ContractAddress;
//     fn set_staking_reward_rate(ref self: CS, rate: u256);
//     fn get_staking_reward_rate(self: @CS) -> u256;
//     fn set_min_staking_amount(ref self: CS, amount: u256);
//     fn get_min_staking_amount(self: @CS) -> u256;
//     fn set_max_staking_duration(ref self: CS, duration: u64);
//     fn get_max_staking_duration(self: @CS) -> u64;
// }

// // Data structures
// #[derive(Drop, Serde, starknet::Store)]
// pub struct StakingInfo {
//     pub amount: u256,
//     pub start_time: u64,
//     pub duration: u64,
//     pub is_active: bool,
// }

// // Contract implementation
// #[starknet::contract]
// pub mod KRCStaking {
//     use OwnableComponent::InternalTrait;
//     use core::integer::u256;
//     use openzeppelin_access::ownable::OwnableComponent;
//     use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
//     use starknet::storage::{
//         Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
//         StoragePointerWriteAccess,
//     };
//     use super::{
//         ContractAddress, EventEmitter, StakingInfo, get_block_timestamp, get_caller_address,
//         get_contract_address,
//     };

//     component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

//     #[abi(embed_v0)]
//     impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
//     impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;

//     // Events
//     #[event]
//     #[derive(Drop, starknet::Event)]
//     pub enum Event {
//         StakingStarted: StakingStarted,
//         StakingEnded: StakingEnded,
//         EmergencyWithdraw: EmergencyWithdraw,
//         KRCContractSet: KRCContractSet,
//         StakingRewardRateSet: StakingRewardRateSet,
//         MinStakingAmountSet: MinStakingAmountSet,
//         MaxStakingDurationSet: MaxStakingDurationSet,
//         #[flat]
//         OwnableEvent: OwnableComponent::Event,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct StakingStarted {
//         pub user: ContractAddress,
//         pub amount: u256,
//         pub duration: u64,
//         pub timestamp: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct StakingEnded {
//         pub user: ContractAddress,
//         pub amount: u256,
//         pub rewards: u256,
//         pub timestamp: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct EmergencyWithdraw {
//         pub user: ContractAddress,
//         pub amount: u256,
//         pub timestamp: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct KRCContractSet {
//         pub krc_contract: ContractAddress,
//         pub timestamp: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct StakingRewardRateSet {
//         pub rate: u256,
//         pub timestamp: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct MinStakingAmountSet {
//         pub amount: u256,
//         pub timestamp: u64,
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct MaxStakingDurationSet {
//         pub duration: u64,
//         pub timestamp: u64,
//     }

//     // Storage
//     #[storage]
//     struct Storage {
//         #[substorage(v0)]
//         ownable: OwnableComponent::Storage,
//         // KRC contract address
//         krc_contract: ContractAddress,
//         // Staking state
//         user_staking_amount: Map<ContractAddress, u256>,
//         user_staking_start: Map<ContractAddress, u64>,
//         user_staking_duration: Map<ContractAddress, u64>,
//         user_total_staking_rewards: Map<ContractAddress, u256>,
//         total_staked: u256,
//         total_staking_rewards: u256,
//         // Configuration
//         staking_reward_rate: u256,
//         min_staking_amount: u256,
//         max_staking_duration: u64,
//     }

//     // Constructor
//     #[constructor]
//     fn constructor(ref self: ContractState, owner: ContractAddress) {
//         // Initialize Ownable
//         self.ownable.initializer(owner);

//         // Set default configuration
//         self.staking_reward_rate.write(1000); // 10% APY in basis points
//         self.min_staking_amount.write(1000000000000000000000); // 1000 KRC
//         self.max_staking_duration.write(31536000); // 365 days in seconds
//     }

//     // Modifiers
//     fn only_owner(self: @ContractState) {
//         self.ownable.assert_only_owner();
//     }

//     fn valid_amount(amount: u256) {
//         assert(amount > 0, 'Amount > 0');
//     }

//     fn valid_duration(self: @ContractState, duration: u64) {
//         assert(duration >= 2592000, 'Duration too short'); // 30 days
//         let max_duration = self.max_staking_duration.read();
//         assert(duration <= max_duration, 'Duration too long');
//     }

//     fn only_staker(self: @ContractState) {
//         let caller = get_caller_address();
//         let staking_amount = self.user_staking_amount.read(caller);
//         assert(staking_amount > 0, 'No active staking');
//     }

//     fn zero_address() -> ContractAddress {
//         let zero: felt252 = 0;
//         zero.try_into().unwrap()
//     }

//     // Implementation
//     #[abi(embed_v0)]
//     impl IKRCStakingImpl of super::IKRCStaking<ContractState> {
//         fn start_staking(ref self: ContractState, amount: u256, duration: u64) {
//             valid_amount(amount);
//             valid_duration(@self, duration);

//             let caller = get_caller_address();
//             let krc_contract = self.krc_contract.read();
//             assert(krc_contract != zero_address(), 'KRC contract not set');

//             let krc_dispatcher = IERC20Dispatcher { contract_address: krc_contract };
//             let balance = krc_dispatcher.balance_of(caller);
//             let current_staking = self.user_staking_amount.read(caller);

//             assert(balance >= amount, 'Insufficient KRC balance');
//             assert(current_staking == 0, 'Already staking');

//             let min_amount = self.min_staking_amount.read();
//             assert(amount >= min_amount, 'Amount below minimum');

//             let timestamp = get_block_timestamp();

//             self.user_staking_amount.write(caller, amount);
//             self.user_staking_start.write(caller, timestamp);
//             self.user_staking_duration.write(caller, duration);

//             // Transfer tokens to contract for staking
//             krc_dispatcher.transfer_from(caller, get_contract_address(), amount);

//             let current_total_staked = self.total_staked.read();
//             let new_total_staked = current_total_staked + amount;
//             self.total_staked.write(new_total_staked);

//             self.emit(StakingStarted { user: caller, amount, duration, timestamp });
//         }

//         fn end_staking(ref self: ContractState) {
//             only_staker(@self);

//             let caller = get_caller_address();
//             let staking_amount = self.user_staking_amount.read(caller);
//             let staking_start = self.user_staking_start.read(caller);
//             let staking_duration = self.user_staking_duration.read(caller);

//             let timestamp = get_block_timestamp();
//             assert(timestamp >= staking_start + staking_duration, 'Staking period not ended');

//             let staking_reward_rate = self.staking_reward_rate.read();
//             let time_staked = timestamp - staking_start;
//             let time_staked_u256 = time_staked.into();
//             let rewards = (staking_amount * staking_reward_rate * time_staked_u256)
//                 / (10000 * 365 * 24 * 3600);

//             // Transfer staked tokens and rewards back to user
//             let krc_contract = self.krc_contract.read();
//             let krc_dispatcher = IERC20Dispatcher { contract_address: krc_contract };

//             krc_dispatcher.transfer(caller, staking_amount);

//             // Mint rewards if needed (this would require KRC contract to have mint function)
//             // For now, we'll assume rewards are pre-minted or handled differently
//             if rewards > 0 {
//                 krc_dispatcher.transfer(caller, rewards);
//             }

//             let current_total_rewards = self.user_total_staking_rewards.read(caller);
//             let new_total_rewards = current_total_rewards + rewards;
//             self.user_total_staking_rewards.write(caller, new_total_rewards);

//             let current_total_staked = self.total_staked.read();
//             let new_total_staked = current_total_staked - staking_amount;
//             self.total_staked.write(new_total_staked);

//             self.user_staking_amount.write(caller, 0);
//             self.user_staking_start.write(caller, 0);
//             self.user_staking_duration.write(caller, 0);

//             self.emit(StakingEnded { user: caller, amount: staking_amount, rewards, timestamp });
//         }

//         fn emergency_withdraw(ref self: ContractState) {
//             only_owner(@self);

//             let caller = get_caller_address();
//             let staking_amount = self.user_staking_amount.read(caller);

//             if staking_amount > 0 {
//                 let krc_contract = self.krc_contract.read();
//                 let krc_dispatcher = IERC20Dispatcher { contract_address: krc_contract };

//                 krc_dispatcher.transfer(caller, staking_amount);

//                 self.user_staking_amount.write(caller, 0);
//                 self.user_staking_start.write(caller, 0);
//                 self.user_staking_duration.write(caller, 0);

//                 let current_total_staked = self.total_staked.read();
//                 let new_total_staked = current_total_staked - staking_amount;
//                 self.total_staked.write(new_total_staked);

//                 self
//                     .emit(
//                         EmergencyWithdraw {
//                             user: caller, amount: staking_amount, timestamp:
//                             get_block_timestamp(),
//                         },
//                     );
//             }
//         }

//         fn get_user_staking_info(self: @ContractState, user: ContractAddress) -> StakingInfo {
//             let amount = self.user_staking_amount.read(user);
//             let start_time = self.user_staking_start.read(user);
//             let duration = self.user_staking_duration.read(user);
//             let is_active = amount > 0;

//             StakingInfo { amount, start_time, duration, is_active }
//         }

//         fn get_total_staked(self: @ContractState) -> u256 {
//             self.total_staked.read()
//         }

//         fn get_total_staking_rewards(self: @ContractState) -> u256 {
//             self.total_staking_rewards.read()
//         }

//         fn get_user_staking_rewards(self: @ContractState, user: ContractAddress) -> u256 {
//             self.user_total_staking_rewards.read(user)
//         }

//         fn set_krc_contract(ref self: ContractState, krc_contract: ContractAddress) {
//             only_owner(@self);
//             self.krc_contract.write(krc_contract);
//             self.emit(KRCContractSet { krc_contract, timestamp: get_block_timestamp() });
//         }

//         fn get_krc_contract(self: @ContractState) -> ContractAddress {
//             self.krc_contract.read()
//         }

//         fn set_staking_reward_rate(ref self: ContractState, rate: u256) {
//             only_owner(@self);
//             self.staking_reward_rate.write(rate);
//             self.emit(StakingRewardRateSet { rate, timestamp: get_block_timestamp() });
//         }

//         fn get_staking_reward_rate(self: @ContractState) -> u256 {
//             self.staking_reward_rate.read()
//         }

//         fn set_min_staking_amount(ref self: ContractState, amount: u256) {
//             only_owner(@self);
//             self.min_staking_amount.write(amount);
//             self.emit(MinStakingAmountSet { amount, timestamp: get_block_timestamp() });
//         }

//         fn get_min_staking_amount(self: @ContractState) -> u256 {
//             self.min_staking_amount.read()
//         }

//         fn set_max_staking_duration(ref self: ContractState, duration: u64) {
//             only_owner(@self);
//             self.max_staking_duration.write(duration);
//             self.emit(MaxStakingDurationSet { duration, timestamp: get_block_timestamp() });
//         }

//         fn get_max_staking_duration(self: @ContractState) -> u64 {
//             self.max_staking_duration.read()
//         }
//     }
// }
