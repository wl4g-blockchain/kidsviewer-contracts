// SPDX-License-Identifier: MIT

use core::integer::u256;
use starknet::{ContractAddress, get_caller_address};

// Interface definition
#[starknet::interface]
pub trait IKRC<ContractState> {
    // ERC20 functions
    fn name(self: @ContractState) -> ByteArray;
    fn symbol(self: @ContractState) -> ByteArray;
    fn decimals(self: @ContractState) -> u8;
    fn total_supply(self: @ContractState) -> u256;
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256;
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256);
    fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    );

    // Custom KRC functions
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: ContractState, amount: u256);
    fn pause(ref self: ContractState);
    fn unpause(ref self: ContractState);

    // Additional view functions for testing
    fn max_supply(self: @ContractState) -> u256;
    fn initial_supply(self: @ContractState) -> u256;
    fn paused(self: @ContractState) -> bool;
}

// Contract implementation
#[starknet::contract]
pub mod KRC {
    use OwnableComponent::InternalTrait;
    use core::integer::u256;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_token::erc20::ERC20Component::{
        ERC20HooksTrait, InternalTrait as ERC20InternalTrait,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{ContractAddress, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        paused: bool,
        // Constants
        max_supply: u256,
        initial_supply: u256,
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize Ownable
        self.ownable.initializer(owner);

        // Initialize ERC20
        let name = "KRC";
        let symbol = "KRC";
        self.erc20.initializer(name, symbol);

        // Set constants
        let max_supply_val = 100000000000000000000000000; // 100M KRC
        let initial_supply_val = 10000000000000000000000000; // 10M KRC

        self.max_supply.write(max_supply_val);
        self.initial_supply.write(initial_supply_val);

        // Mint initial supply to owner
        self.erc20.mint(owner, initial_supply_val);
    }

    // Modifiers
    fn only_owner(self: @ContractState) {
        self.ownable.assert_only_owner();
    }

    fn when_not_paused(self: @ContractState) {
        let is_paused = self.paused.read();
        assert(!is_paused, 'Paused');
    }

    fn valid_amount(amount: u256) {
        assert(amount > 0, 'Amount > 0');
    }


    fn zero_address() -> ContractAddress {
        let zero: felt252 = 0;
        zero.try_into().unwrap()
    }

    // Implementation
    #[abi(embed_v0)]
    impl IKRCImpl of super::IKRC<ContractState> {
        // ERC20 functions (delegated to ERC20Component)
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.transfer(recipient, amount);
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            self.erc20.approve(spender, amount);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            self.erc20.transfer_from(sender, recipient, amount);
        }

        // Custom KRC functions
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            only_owner(@self);
            valid_amount(amount);

            let current_supply = self.erc20.total_supply();
            let max_supply_val = self.max_supply.read();
            let new_supply = current_supply + amount;
            assert(new_supply <= max_supply_val, 'Exceeds max supply');

            self.erc20.mint(to, amount);
        }

        fn burn(ref self: ContractState, amount: u256) {
            valid_amount(amount);

            let caller = get_caller_address();
            let current_balance = self.erc20.balance_of(caller);
            assert(current_balance >= amount, 'Insufficient');

            self.erc20.burn(caller, amount);
        }

        fn pause(ref self: ContractState) {
            only_owner(@self);
            self.paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            only_owner(@self);
            self.paused.write(false);
        }

        // Additional view functions for testing
        fn max_supply(self: @ContractState) -> u256 {
            self.max_supply.read()
        }

        fn initial_supply(self: @ContractState) -> u256 {
            self.initial_supply.read()
        }

        fn paused(self: @ContractState) -> bool {
            self.paused.read()
        }
    }

    // ERC20 Hooks implementation
    impl ERC20HooksImpl of ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) { // Check if paused
            let is_paused = self.get_contract().paused.read();
            assert(!is_paused, 'Paused');
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) { // No additional logic needed after update
        }
    }
}
