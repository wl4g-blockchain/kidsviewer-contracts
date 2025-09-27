// SPDX-License-Identifier: MIT

use core::felt252;
use core::integer::u256;
use starknet::event::EventEmitter;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

// Interface definition
#[starknet::interface]
pub trait IKidsViewerPiggyBank<CS> {
    fn receive_reward(ref self: CS, person_id: u64, token: ContractAddress, amount: u256);
    fn request_withdrawal(ref self: CS, person_id: u64, token: ContractAddress, amount: u256, reason: felt252);
    fn approve_withdrawal(ref self: CS, request_id: u64);
    fn reject_withdrawal(ref self: CS, request_id: u64, reason: felt252);
    fn invest_in_aave(
        ref self: CS, person_id: u64, token: ContractAddress, amount: u256, aave_product: ContractAddress,
    );
    fn recover_all_investments(ref self: CS, person_id: u64, token: ContractAddress);
    fn set_parent_approval(ref self: CS, person_id: u64, approved: bool);
    fn set_investment_config(ref self: CS, person_id: u64, enabled: bool, max_amount: u256);
    fn set_aave_product_approval(
        ref self: CS, person_id: u64, aave_product: ContractAddress, approved: bool,
    );
    fn set_person_active(ref self: CS, person_id: u64, active: bool);
    fn pause(ref self: CS);
    fn unpause(ref self: CS);
    fn get_person_balance(self: @CS, person_id: u64, token: ContractAddress) -> u256;
    fn get_person_earnings(
        self: @CS, person_id: u64, token: ContractAddress,
    ) -> (u256, u256);
    fn get_withdrawal_request(
        self: @CS, request_id: u64,
    ) -> (u64, ContractAddress, u256, felt252, bool, bool, felt252);
    fn get_person_withdrawal_requests(self: @CS, person_id: u64) -> u64;
    fn get_investment_config(self: @CS, person_id: u64) -> (bool, u256, u256);
    fn is_aave_product_approved(
        self: @CS, person_id: u64, aave_product: ContractAddress,
    ) -> bool;
    fn is_parent_approved(self: @CS, parent: ContractAddress, person_id: u64) -> bool;
    fn is_person_active(self: @CS, person_id: u64) -> bool;
    fn paused(self: @CS) -> bool;
    fn owner(self: @CS) -> ContractAddress;
    fn next_request_id(self: @CS) -> u64;
    fn person_balances(self: @CS, person_id: u64, token: ContractAddress) -> u256;
    fn person_earnings(self: @CS, person_id: u64, token: ContractAddress) -> u256;
    fn person_request_ids(self: @CS, person_id: u64) -> u64;
    fn parent_approvals(self: @CS, parent: ContractAddress, person_id: u64) -> bool;
    fn aave_product_approvals(
        self: @CS, person_id: u64, aave_product: ContractAddress,
    ) -> bool;
    fn child_active(self: @CS, child: ContractAddress) -> bool;
}

// Contract implementation
#[starknet::contract]
pub mod KidsViewerPiggyBank {
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
        RewardReceived: RewardReceived,
        WithdrawalRequested: WithdrawalRequested,
        WithdrawalApproved: WithdrawalApproved,
        WithdrawalRejected: WithdrawalRejected,
        InvestmentMade: InvestmentMade,
        InvestmentRecovered: InvestmentRecovered,
        ParentApprovalUpdated: ParentApprovalUpdated,
        InvestmentConfigUpdated: InvestmentConfigUpdated,
        AaveProductApprovalUpdated: AaveProductApprovalUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardReceived {
        pub child: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalRequested {
        pub child: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub reason: felt252,
        pub request_id: u64,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalApproved {
        pub child: ContractAddress,
        pub request_id: u64,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalRejected {
        pub child: ContractAddress,
        pub request_id: u64,
        pub reason: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestmentMade {
        pub child: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub aave_product: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestmentRecovered {
        pub child: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ParentApprovalUpdated {
        pub parent: ContractAddress,
        pub child: ContractAddress,
        pub approved: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestmentConfigUpdated {
        pub child: ContractAddress,
        pub enabled: bool,
        pub max_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AaveProductApprovalUpdated {
        pub child: ContractAddress,
        pub aave_product: ContractAddress,
        pub approved: bool,
        pub timestamp: u64,
    }

    // Storage
    #[storage]
    struct Storage {
        pub owner: ContractAddress,
        pub paused: bool,
        pub next_request_id: u64,
        pub child_balances: Map<(ContractAddress, ContractAddress), u256>,
        pub child_earnings: Map<(ContractAddress, ContractAddress), u256>,
        pub withdrawal_requests: Map<
            u64, (ContractAddress, ContractAddress, u256, felt252, bool, bool, felt252),
        >,
        pub child_request_ids: Map<ContractAddress, u64>,
        pub parent_approvals: Map<(ContractAddress, ContractAddress), bool>,
        pub investment_configs: Map<ContractAddress, (bool, u256, u256)>,
        pub aave_product_approvals: Map<(ContractAddress, ContractAddress), bool>,
        pub child_active: Map<ContractAddress, bool>,
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState) {
        let caller = get_caller_address();
        self.owner.write(caller);
        self.next_request_id.write(1);
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

    fn only_parent(self: @ContractState, child: ContractAddress) {
        let caller = get_caller_address();
        let approved = self.parent_approvals.read((caller, child));
        assert(approved, 'Not authorized');
    }

    fn valid_amount(amount: u256) {
        assert(amount > 0, 'Amount > 0');
    }

    // Implementation
    #[abi(embed_v0)]
    impl IKidsViewerPiggyBankImpl of super::IKidsViewerPiggyBank<ContractState> {
        fn receive_reward(
            ref self: ContractState, child: ContractAddress, token: ContractAddress, amount: u256,
        ) {
            when_not_paused(@self);
            valid_amount(amount);
            only_parent(@self, child);

            let current_balance = self.child_balances.read((child, token));
            let new_balance = current_balance + amount;
            self.child_balances.write((child, token), new_balance);

            let current_earnings = self.child_earnings.read((child, token));
            let new_earnings = current_earnings + amount;
            self.child_earnings.write((child, token), new_earnings);

            let timestamp = get_block_timestamp();
            self.emit(RewardReceived { child, token, amount, timestamp });
        }

        fn request_withdrawal(
            ref self: ContractState, token: ContractAddress, amount: u256, reason: felt252,
        ) {
            when_not_paused(@self);
            valid_amount(amount);

            let caller = get_caller_address();
            let current_balance = self.child_balances.read((caller, token));
            assert(current_balance >= amount, 'Insufficient');

            let request_id = self.next_request_id.read();
            let timestamp = get_block_timestamp();

            self
                .withdrawal_requests
                .write(request_id, (caller, token, amount, reason, false, false, reason));
            self.child_request_ids.write(caller, request_id);
            self.next_request_id.write(request_id + 1);

            self
                .emit(
                    WithdrawalRequested {
                        child: caller, token, amount, reason, request_id, timestamp,
                    },
                );
        }

        fn approve_withdrawal(ref self: ContractState, request_id: u64) {
            only_owner(@self);
            when_not_paused(@self);

            let (child, token, amount, reason, approved, executed, _) = self
                .withdrawal_requests
                .read(request_id);
            assert(!approved, 'Already approved');
            assert(!executed, 'Already executed');

            self
                .withdrawal_requests
                .write(request_id, (child, token, amount, reason, true, false, reason));

            let current_balance = self.child_balances.read((child, token));
            let new_balance = current_balance - amount;
            self.child_balances.write((child, token), new_balance);

            let current_timestamp = get_block_timestamp();
            self.emit(WithdrawalApproved { child, request_id, timestamp: current_timestamp });
        }

        fn reject_withdrawal(ref self: ContractState, request_id: u64, reason: felt252) {
            only_owner(@self);
            when_not_paused(@self);

            let (child, token, amount, _, approved, executed, _) = self
                .withdrawal_requests
                .read(request_id);
            assert(!approved, 'Already approved');
            assert(!executed, 'Already executed');

            self
                .withdrawal_requests
                .write(request_id, (child, token, amount, reason, false, true, reason));

            let current_timestamp = get_block_timestamp();
            self
                .emit(
                    WithdrawalRejected { child, request_id, reason, timestamp: current_timestamp },
                );
        }

        fn invest_in_aave(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            aave_product: ContractAddress,
        ) {
            when_not_paused(@self);
            valid_amount(amount);

            let caller = get_caller_address();
            let current_balance = self.child_balances.read((caller, token));
            assert(current_balance >= amount, 'Insufficient');

            let new_balance = current_balance - amount;
            self.child_balances.write((caller, token), new_balance);

            let timestamp = get_block_timestamp();
            self.emit(InvestmentMade { child: caller, token, amount, aave_product, timestamp });
        }

        fn recover_all_investments(
            ref self: ContractState, child: ContractAddress, token: ContractAddress,
        ) {
            let caller = get_caller_address();
            let is_approved = self.parent_approvals.read((caller, child));
            assert(is_approved, 'Not authorized');
            when_not_paused(@self);

            let current_balance = self.child_balances.read((child, token));
            let recovered_amount = current_balance;

            self.child_balances.write((child, token), 0);

            let timestamp = get_block_timestamp();
            self.emit(InvestmentRecovered { child, token, amount: recovered_amount, timestamp });
        }

        fn set_parent_approval(ref self: ContractState, child: ContractAddress, approved: bool) {
            let caller = get_caller_address();
            self.parent_approvals.write((caller, child), approved);

            let timestamp = get_block_timestamp();
            self.emit(ParentApprovalUpdated { parent: caller, child, approved, timestamp });
        }

        fn set_investment_config(
            ref self: ContractState, child: ContractAddress, enabled: bool, max_amount: u256,
        ) {
            let caller = get_caller_address();
            let is_approved = self.parent_approvals.read((caller, child));
            assert(is_approved, 'Not authorized');

            let new_config = (enabled, max_amount, 0);
            self.investment_configs.write(child, new_config);

            let timestamp = get_block_timestamp();
            self.emit(InvestmentConfigUpdated { child, enabled, max_amount, timestamp });
        }

        fn set_aave_product_approval(
            ref self: ContractState,
            child: ContractAddress,
            aave_product: ContractAddress,
            approved: bool,
        ) {
            let caller = get_caller_address();
            let is_approved = self.parent_approvals.read((caller, child));
            assert(is_approved, 'Not authorized');

            self.aave_product_approvals.write((child, aave_product), approved);

            let timestamp = get_block_timestamp();
            self.emit(AaveProductApprovalUpdated { child, aave_product, approved, timestamp });
        }

        fn set_child_active(ref self: ContractState, child: ContractAddress, active: bool) {
            only_owner(@self);
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

        fn get_child_balance(
            self: @ContractState, child: ContractAddress, token: ContractAddress,
        ) -> u256 {
            self.child_balances.read((child, token))
        }

        fn get_child_earnings(
            self: @ContractState, child: ContractAddress, token: ContractAddress,
        ) -> (u256, u256) {
            let balance = self.child_balances.read((child, token));
            let earnings = self.child_earnings.read((child, token));
            (balance, earnings)
        }

        fn get_withdrawal_request(
            self: @ContractState, request_id: u64,
        ) -> (ContractAddress, ContractAddress, u256, felt252, bool, bool, felt252) {
            self.withdrawal_requests.read(request_id)
        }

        fn get_child_withdrawal_requests(self: @ContractState, child: ContractAddress) -> u64 {
            self.child_request_ids.read(child)
        }

        fn get_investment_config(
            self: @ContractState, child: ContractAddress,
        ) -> (bool, u256, u256) {
            self.investment_configs.read(child)
        }

        fn is_aave_product_approved(
            self: @ContractState, child: ContractAddress, aave_product: ContractAddress,
        ) -> bool {
            self.aave_product_approvals.read((child, aave_product))
        }

        fn is_parent_approved(
            self: @ContractState, parent: ContractAddress, child: ContractAddress,
        ) -> bool {
            self.parent_approvals.read((parent, child))
        }

        fn is_child_active(self: @ContractState, child: ContractAddress) -> bool {
            self.child_active.read(child)
        }

        fn paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn next_request_id(self: @ContractState) -> u64 {
            self.next_request_id.read()
        }

        fn child_balances(
            self: @ContractState, child: ContractAddress, token: ContractAddress,
        ) -> u256 {
            self.child_balances.read((child, token))
        }

        fn child_earnings(
            self: @ContractState, child: ContractAddress, token: ContractAddress,
        ) -> u256 {
            self.child_earnings.read((child, token))
        }

        fn child_request_ids(self: @ContractState, child: ContractAddress) -> u64 {
            self.child_request_ids.read(child)
        }

        fn parent_approvals(
            self: @ContractState, parent: ContractAddress, child: ContractAddress,
        ) -> bool {
            self.parent_approvals.read((parent, child))
        }

        fn aave_product_approvals(
            self: @ContractState, child: ContractAddress, aave_product: ContractAddress,
        ) -> bool {
            self.aave_product_approvals.read((child, aave_product))
        }

        fn child_active(self: @ContractState, child: ContractAddress) -> bool {
            self.child_active.read(child)
        }
    }
}
