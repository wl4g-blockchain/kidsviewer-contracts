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
    fn person_active(self: @CS, person_id: u64) -> bool;
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
        pub person_id: u64,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalRequested {
        pub person_id: u64,
        pub token: ContractAddress,
        pub amount: u256,
        pub reason: felt252,
        pub request_id: u64,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalApproved {
        pub person_id: u64,
        pub request_id: u64,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalRejected {
        pub person_id: u64,
        pub request_id: u64,
        pub reason: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestmentMade {
        pub person_id: u64,
        pub token: ContractAddress,
        pub amount: u256,
        pub aave_product: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestmentRecovered {
        pub person_id: u64,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ParentApprovalUpdated {
        pub parent: ContractAddress,
        pub person_id: u64,
        pub approved: bool,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InvestmentConfigUpdated {
        pub person_id: u64,
        pub enabled: bool,
        pub max_amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AaveProductApprovalUpdated {
        pub person_id: u64,
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
        pub person_balances: Map<(u64, ContractAddress), u256>,
        pub person_earnings: Map<(u64, ContractAddress), u256>,
        pub withdrawal_requests: Map<
            u64, (u64, ContractAddress, u256, felt252, bool, bool, felt252),
        >,
        pub person_request_ids: Map<u64, u64>,
        pub parent_approvals: Map<(ContractAddress, u64), bool>,
        pub investment_configs: Map<u64, (bool, u256, u256)>,
        pub aave_product_approvals: Map<(u64, ContractAddress), bool>,
        pub person_active: Map<u64, bool>,
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

    fn only_parent(self: @ContractState, person_id: u64) {
        let caller = get_caller_address();
        let approved = self.parent_approvals.read((caller, person_id));
        assert(approved, 'Not authorized');
    }

    fn valid_amount(amount: u256) {
        assert(amount > 0, 'Amount > 0');
    }

    // Implementation
    #[abi(embed_v0)]
    impl IKidsViewerPiggyBankImpl of super::IKidsViewerPiggyBank<ContractState> {
        fn receive_reward(
            ref self: ContractState, person_id: u64, token: ContractAddress, amount: u256,
        ) {
            when_not_paused(@self);
            valid_amount(amount);
            only_parent(@self, person_id);

            let current_balance = self.person_balances.read((person_id, token));
            let new_balance = current_balance + amount;
            self.person_balances.write((person_id, token), new_balance);

            let current_earnings = self.person_earnings.read((person_id, token));
            let new_earnings = current_earnings + amount;
            self.person_earnings.write((person_id, token), new_earnings);

            let timestamp = get_block_timestamp();
            self.emit(RewardReceived { person_id, token, amount, timestamp });
        }

        fn request_withdrawal(
            ref self: ContractState, person_id: u64, token: ContractAddress, amount: u256, reason: felt252,
        ) {
            when_not_paused(@self);
            valid_amount(amount);

            let caller = get_caller_address();
            let current_balance = self.person_balances.read((person_id, token));
            assert(current_balance >= amount, 'Insufficient');

            let request_id = self.next_request_id.read();
            let timestamp = get_block_timestamp();

            self
                .withdrawal_requests
                .write(request_id, (person_id, token, amount, reason, false, false, reason));
            self.person_request_ids.write(person_id, request_id);
            self.next_request_id.write(request_id + 1);

            self
                .emit(
                    WithdrawalRequested {
                        person_id, token, amount, reason, request_id, timestamp,
                    },
                );
        }

        fn approve_withdrawal(ref self: ContractState, request_id: u64) {
            only_owner(@self);
            when_not_paused(@self);

            let (person_id, token, amount, reason, approved, executed, _) = self
                .withdrawal_requests
                .read(request_id);
            assert(!approved, 'Already approved');
            assert(!executed, 'Already executed');

            self
                .withdrawal_requests
                .write(request_id, (person_id, token, amount, reason, true, false, reason));

            let current_balance = self.person_balances.read((person_id, token));
            let new_balance = current_balance - amount;
            self.person_balances.write((person_id, token), new_balance);

            let current_timestamp = get_block_timestamp();
            self.emit(WithdrawalApproved { person_id, request_id, timestamp: current_timestamp });
        }

        fn reject_withdrawal(ref self: ContractState, request_id: u64, reason: felt252) {
            only_owner(@self);
            when_not_paused(@self);

            let (person_id, token, amount, _, approved, executed, _) = self
                .withdrawal_requests
                .read(request_id);
            assert(!approved, 'Already approved');
            assert(!executed, 'Already executed');

            let (person_id, token, amount, reason, approved, executed, _) = self.withdrawal_requests.read(request_id);
            self
                .withdrawal_requests
                .write(request_id, (person_id, token, amount, reason, false, true, reason));

            let current_timestamp = get_block_timestamp();
            self
                .emit(
                    WithdrawalRejected { person_id, request_id, reason, timestamp: current_timestamp },
                );
        }

        fn invest_in_aave(
            ref self: ContractState,
            person_id: u64,
            token: ContractAddress,
            amount: u256,
            aave_product: ContractAddress,
        ) {
            when_not_paused(@self);
            valid_amount(amount);
            only_parent(@self, person_id);

            let current_balance = self.person_balances.read((person_id, token));
            assert(current_balance >= amount, 'Insufficient');

            let new_balance = current_balance - amount;
            self.person_balances.write((person_id, token), new_balance);

            let timestamp = get_block_timestamp();
            self.emit(InvestmentMade { person_id, token, amount, aave_product, timestamp });
        }

        fn recover_all_investments(
            ref self: ContractState, person_id: u64, token: ContractAddress,
        ) {
            only_parent(@self, person_id);
            when_not_paused(@self);

            let current_balance = self.person_balances.read((person_id, token));
            let recovered_amount = current_balance;

            self.person_balances.write((person_id, token), 0);

            let timestamp = get_block_timestamp();
            self.emit(InvestmentRecovered { person_id, token, amount: recovered_amount, timestamp });
        }

        fn set_parent_approval(ref self: ContractState, person_id: u64, approved: bool) {
            let caller = get_caller_address();
            self.parent_approvals.write((caller, person_id), approved);

            let timestamp = get_block_timestamp();
            self.emit(ParentApprovalUpdated { parent: caller, person_id, approved, timestamp });
        }

        fn set_investment_config(
            ref self: ContractState, person_id: u64, enabled: bool, max_amount: u256,
        ) {
            let caller = get_caller_address();
            let is_approved = self.parent_approvals.read((caller, person_id));
            assert(is_approved, 'Not authorized');

            let new_config = (enabled, max_amount, 0);
            self.investment_configs.write(person_id, new_config);

            let timestamp = get_block_timestamp();
            self.emit(InvestmentConfigUpdated { person_id, enabled, max_amount, timestamp });
        }

        fn set_aave_product_approval(
            ref self: ContractState,
            person_id: u64,
            aave_product: ContractAddress,
            approved: bool,
        ) {
            let caller = get_caller_address();
            let is_approved = self.parent_approvals.read((caller, person_id));
            assert(is_approved, 'Not authorized');

            self.aave_product_approvals.write((person_id, aave_product), approved);

            let timestamp = get_block_timestamp();
            self.emit(AaveProductApprovalUpdated { person_id, aave_product, approved, timestamp });
        }

        fn set_person_active(ref self: ContractState, person_id: u64, active: bool) {
            only_owner(@self);
            self.person_active.write(person_id, active);
        }

        fn pause(ref self: ContractState) {
            only_owner(@self);
            self.paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            only_owner(@self);
            self.paused.write(false);
        }

        fn get_person_balance(
            self: @ContractState, person_id: u64, token: ContractAddress,
        ) -> u256 {
            self.person_balances.read((person_id, token))
        }

        fn get_person_earnings(
            self: @ContractState, person_id: u64, token: ContractAddress,
        ) -> (u256, u256) {
            let balance = self.person_balances.read((person_id, token));
            let earnings = self.person_earnings.read((person_id, token));
            (balance, earnings)
        }

        fn get_withdrawal_request(
            self: @ContractState, request_id: u64,
        ) -> (u64, ContractAddress, u256, felt252, bool, bool, felt252) {
            self.withdrawal_requests.read(request_id)
        }

        fn get_person_withdrawal_requests(self: @ContractState, person_id: u64) -> u64 {
            self.person_request_ids.read(person_id)
        }

        fn get_investment_config(
            self: @ContractState, person_id: u64,
        ) -> (bool, u256, u256) {
            self.investment_configs.read(person_id)
        }

        fn is_aave_product_approved(
            self: @ContractState, person_id: u64, aave_product: ContractAddress,
        ) -> bool {
            self.aave_product_approvals.read((person_id, aave_product))
        }

        fn is_parent_approved(
            self: @ContractState, parent: ContractAddress, person_id: u64,
        ) -> bool {
            self.parent_approvals.read((parent, person_id))
        }

        fn is_person_active(self: @ContractState, person_id: u64) -> bool {
            self.person_active.read(person_id)
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

        fn person_balances(
            self: @ContractState, person_id: u64, token: ContractAddress,
        ) -> u256 {
            self.person_balances.read((person_id, token))
        }

        fn person_earnings(
            self: @ContractState, person_id: u64, token: ContractAddress,
        ) -> u256 {
            self.person_earnings.read((person_id, token))
        }

        fn person_request_ids(self: @ContractState, person_id: u64) -> u64 {
            self.person_request_ids.read(person_id)
        }

        fn parent_approvals(
            self: @ContractState, parent: ContractAddress, person_id: u64,
        ) -> bool {
            self.parent_approvals.read((parent, person_id))
        }

        fn aave_product_approvals(
            self: @ContractState, person_id: u64, aave_product: ContractAddress,
        ) -> bool {
            self.aave_product_approvals.read((person_id, aave_product))
        }

        fn person_active(self: @ContractState, person_id: u64) -> bool {
            self.person_active.read(person_id)
        }
    }
}
