// SPDX-License-Identifier: MIT

use core::felt252;
use core::integer::u256;
use starknet::event::EventEmitter;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

// Interface definition
#[starknet::interface]
pub trait IKidsViewerVault<CS> {
    fn add_supported_token(ref self: CS, token: ContractAddress);
    fn remove_supported_token(ref self: CS, token: ContractAddress);
    fn register_parent(ref self: CS, parent: ContractAddress);
    fn authorize_child(ref self: CS, child: ContractAddress, authorized: bool);
    fn set_daily_reward_limit(
        ref self: CS, child: ContractAddress, token: ContractAddress, daily_limit: u256,
    );
    fn deposit(ref self: CS, token: ContractAddress, amount: u256);
    fn withdraw(ref self: CS, token: ContractAddress, amount: u256);
    fn distribute_reward(
        ref self: CS, child: ContractAddress, token: ContractAddress, amount: u256,
    );
    fn set_child_active(ref self: CS, child: ContractAddress, active: bool);
    fn pause(ref self: CS);
    fn unpause(ref self: CS);
    fn emergency_withdraw(ref self: CS, token: ContractAddress, amount: u256);
    // View functions
    fn paused(self: @CS) -> bool;
    fn max_daily_limit(self: @CS) -> u256;
    fn min_daily_limit(self: @CS) -> u256;
    fn get_owner(self: @CS) -> ContractAddress;
    fn supported_tokens(self: @CS, token: ContractAddress) -> bool;
    fn parent_active(self: @CS, parent: ContractAddress) -> bool;
    fn parent_children(self: @CS, parent: ContractAddress, child: ContractAddress) -> bool;
    fn child_daily_limit(self: @CS, child: ContractAddress) -> u256;
    fn parent_balances(self: @CS, parent: ContractAddress, token: ContractAddress) -> u256;
    fn total_vault_balances(self: @CS, token: ContractAddress) -> u256;
    fn child_daily_used(self: @CS, child: ContractAddress) -> u256;
    fn get_parent_balance(self: @CS, parent: ContractAddress, token: ContractAddress) -> u256;
    fn get_child_config(self: @CS, child: ContractAddress) -> (u256, u256, u64, bool);
    fn is_parent_authorized(self: @CS, parent: ContractAddress, child: ContractAddress) -> bool;
    fn get_total_vault_balance(self: @CS, token: ContractAddress) -> u256;
}

// Contract implementation
#[starknet::contract]
pub mod KidsViewerVault {
    use core::integer::u256;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::{ContractAddress, EventEmitter, felt252, get_block_timestamp, get_caller_address};

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        RewardDistributed: RewardDistributed,
        DailyLimitUpdated: DailyLimitUpdated,
        ParentAuthorized: ParentAuthorized,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposit {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdraw {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardDistributed {
        pub child: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DailyLimitUpdated {
        pub child: ContractAddress,
        pub token: ContractAddress,
        pub new_limit: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ParentAuthorized {
        pub parent: ContractAddress,
        pub child: ContractAddress,
        pub authorized: bool,
        pub timestamp: u64,
    }

    // Storage
    #[storage]
    struct Storage {
        pub owner: ContractAddress,
        pub paused: bool,
        pub max_daily_limit: u256,
        pub min_daily_limit: u256,
        pub parent_active: Map<ContractAddress, bool>,
        pub parent_children: Map<(ContractAddress, ContractAddress), bool>,
        pub parent_balances: Map<(ContractAddress, ContractAddress), u256>,
        pub child_daily_limit: Map<ContractAddress, u256>,
        pub child_daily_used: Map<ContractAddress, u256>,
        pub child_last_reset: Map<ContractAddress, u64>,
        pub child_active: Map<ContractAddress, bool>,
        pub supported_tokens: Map<ContractAddress, bool>,
        pub total_vault_balances: Map<ContractAddress, u256>,
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, max_limit: u256, min_limit: u256) {
        let caller = get_caller_address();
        self.owner.write(caller);
        self.max_daily_limit.write(max_limit);
        self.min_daily_limit.write(min_limit);
    }

    // Modifiers
    fn only_owner(self: @ContractState) {
        let caller = get_caller_address();
        let owner = self.owner.read();
        assert(caller == owner, 'Caller is not the owner');
    }

    fn when_not_paused(self: @ContractState) {
        let is_paused = self.paused.read();
        assert(!is_paused, 'Paused');
    }

    fn only_parent(self: @ContractState) {
        let caller = get_caller_address();
        let is_active = self.parent_active.read(caller);
        assert(is_active, 'Not authorized');
    }

    fn only_authorized_child(self: @ContractState, child: ContractAddress) {
        let caller = get_caller_address();
        let authorized = self.parent_children.read((caller, child));
        assert(authorized, 'Not authorized');
    }

    fn only_supported_token(self: @ContractState, token: ContractAddress) {
        let is_supported = self.supported_tokens.read(token);
        assert(is_supported, 'Token not supported');
    }

    fn valid_amount(amount: u256) {
        assert(amount > 0, 'Amount > 0');
    }

    // Implementation
    #[abi(embed_v0)]
    impl IKidsViewerVaultImpl of super::IKidsViewerVault<ContractState> {
        fn add_supported_token(ref self: ContractState, token: ContractAddress) {
            only_owner(@self);
            self.supported_tokens.write(token, true);
        }

        fn remove_supported_token(ref self: ContractState, token: ContractAddress) {
            only_owner(@self);
            self.supported_tokens.write(token, false);
        }

        fn register_parent(ref self: ContractState, parent: ContractAddress) {
            only_owner(@self);
            self.parent_active.write(parent, true);
        }

        fn authorize_child(ref self: ContractState, child: ContractAddress, authorized: bool) {
            only_parent(@self);
            let caller = get_caller_address();
            self.parent_children.write((caller, child), authorized);
            let timestamp = get_block_timestamp();
            self.emit(ParentAuthorized { parent: caller, child, authorized, timestamp });
        }

        fn set_daily_reward_limit(
            ref self: ContractState,
            child: ContractAddress,
            token: ContractAddress,
            daily_limit: u256,
        ) {
            only_parent(@self);
            only_authorized_child(@self, child);
            only_supported_token(@self, token);

            let min_limit = self.min_daily_limit.read();
            let max_limit = self.max_daily_limit.read();
            assert(daily_limit >= min_limit, 'Limit too low');
            assert(daily_limit <= max_limit, 'Limit too high');

            self.child_daily_limit.write(child, daily_limit);
            let timestamp = get_block_timestamp();
            self.emit(DailyLimitUpdated { child, token, new_limit: daily_limit, timestamp });
        }

        fn deposit(ref self: ContractState, token: ContractAddress, amount: u256) {
            when_not_paused(@self);
            only_parent(@self);
            only_supported_token(@self, token);
            valid_amount(amount);

            let caller = get_caller_address();
            let current_balance = self.parent_balances.read((caller, token));
            let new_balance = current_balance + amount;
            self.parent_balances.write((caller, token), new_balance);

            let total_balance = self.total_vault_balances.read(token);
            let new_total = total_balance + amount;
            self.total_vault_balances.write(token, new_total);

            let timestamp = get_block_timestamp();
            self.emit(Deposit { caller, token, amount, timestamp });
        }

        fn withdraw(ref self: ContractState, token: ContractAddress, amount: u256) {
            only_parent(@self);
            only_supported_token(@self, token);
            valid_amount(amount);

            let caller = get_caller_address();
            let current_balance = self.parent_balances.read((caller, token));
            assert(current_balance >= amount, 'Insufficient');

            let new_balance = current_balance - amount;
            self.parent_balances.write((caller, token), new_balance);

            let total_balance = self.total_vault_balances.read(token);
            let new_total = total_balance - amount;
            self.total_vault_balances.write(token, new_total);

            let timestamp = get_block_timestamp();
            self.emit(Withdraw { caller, token, amount, timestamp });
        }

        fn distribute_reward(
            ref self: ContractState, child: ContractAddress, token: ContractAddress, amount: u256,
        ) {
            only_parent(@self);
            only_authorized_child(@self, child);
            only_supported_token(@self, token);
            valid_amount(amount);

            let is_active = self.child_active.read(child);
            assert(is_active, 'Child not active');

            let timestamp = get_block_timestamp();
            let last_reset = self.child_last_reset.read(child);

            // Reset daily usage if it's a new day
            if timestamp - last_reset >= 86400 {
                self.child_daily_used.write(child, 0);
                self.child_last_reset.write(child, timestamp);
            }

            let daily_used = self.child_daily_used.read(child);
            let daily_limit = self.child_daily_limit.read(child);
            assert(daily_used + amount <= daily_limit, 'Limit exceeded');

            let caller = get_caller_address();
            let parent_balance = self.parent_balances.read((caller, token));
            assert(parent_balance >= amount, 'Insufficient');

            let new_parent_balance = parent_balance - amount;
            self.parent_balances.write((caller, token), new_parent_balance);
            self.child_daily_used.write(child, daily_used + amount);

            let timestamp = get_block_timestamp();
            self.emit(RewardDistributed { child, token, amount, timestamp });
        }

        fn set_child_active(ref self: ContractState, child: ContractAddress, active: bool) {
            only_parent(@self);
            only_authorized_child(@self, child);
            self.child_active.write(child, active);
        }

        fn pause(ref self: ContractState) {
            only_owner(@self);
            self.paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            only_owner(@self);
            self.paused.write(false);
        }

        fn emergency_withdraw(ref self: ContractState, token: ContractAddress, amount: u256) {
            only_owner(@self);
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            self.emit(Withdraw { caller, token, amount, timestamp });
        }

        fn get_parent_balance(
            self: @ContractState, parent: ContractAddress, token: ContractAddress,
        ) -> u256 {
            self.parent_balances.read((parent, token))
        }

        fn get_child_config(
            self: @ContractState, child: ContractAddress,
        ) -> (u256, u256, u64, bool) {
            let daily_limit = self.child_daily_limit.read(child);
            let daily_used = self.child_daily_used.read(child);
            let last_reset = self.child_last_reset.read(child);
            let is_active = self.child_active.read(child);
            (daily_limit, daily_used, last_reset, is_active)
        }

        fn is_parent_authorized(
            self: @ContractState, parent: ContractAddress, child: ContractAddress,
        ) -> bool {
            self.parent_children.read((parent, child))
        }

        fn get_total_vault_balance(self: @ContractState, token: ContractAddress) -> u256 {
            self.total_vault_balances.read(token)
        }

        // Additional view functions for testing
        fn paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn max_daily_limit(self: @ContractState) -> u256 {
            self.max_daily_limit.read()
        }

        fn min_daily_limit(self: @ContractState) -> u256 {
            self.min_daily_limit.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn supported_tokens(self: @ContractState, token: ContractAddress) -> bool {
            self.supported_tokens.read(token)
        }

        fn parent_active(self: @ContractState, parent: ContractAddress) -> bool {
            self.parent_active.read(parent)
        }

        fn parent_children(
            self: @ContractState, parent: ContractAddress, child: ContractAddress,
        ) -> bool {
            self.parent_children.read((parent, child))
        }

        fn child_daily_limit(self: @ContractState, child: ContractAddress) -> u256 {
            self.child_daily_limit.read(child)
        }

        fn parent_balances(
            self: @ContractState, parent: ContractAddress, token: ContractAddress,
        ) -> u256 {
            self.parent_balances.read((parent, token))
        }

        fn total_vault_balances(self: @ContractState, token: ContractAddress) -> u256 {
            self.total_vault_balances.read(token)
        }

        fn child_daily_used(self: @ContractState, child: ContractAddress) -> u256 {
            self.child_daily_used.read(child)
        }
    }
}
