// SPDX-License-Identifier: MIT

use core::felt252;
use core::integer::u256;
use starknet::event::EventEmitter;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

// Interface definition for KRC Privilege Manager
#[starknet::interface]
pub trait IKRCPrivilegeManager<CS> {
    // Privilege management functions
    fn grant_privilege_access(ref self: CS, user: ContractAddress, feature: felt252);
    fn revoke_privilege_access(ref self: CS, user: ContractAddress, feature: felt252);
    fn has_privilege_access(self: @CS, user: ContractAddress, feature: felt252) -> bool;
    fn get_user_privileges(self: @CS, user: ContractAddress) -> Array<felt252>;

    // Governance functions
    fn create_proposal(
        ref self: CS, title: felt252, description: felt252, proposal_type: felt252, duration: u64,
    );
    fn vote_on_proposal(ref self: CS, proposal_id: u64, support: bool);
    fn execute_proposal(ref self: CS, proposal_id: u64);
    fn get_proposal(self: @CS, proposal_id: u64) -> Proposal;
    fn get_user_votes(self: @CS, user: ContractAddress, proposal_id: u64) -> bool;

    // Privilege level management
    fn update_user_privilege_level(ref self: CS, user: ContractAddress, level: u8);
    fn get_user_privilege_level(self: @CS, user: ContractAddress) -> u8;

    // Access control
    fn set_krc_contract(ref self: CS, krc_contract: ContractAddress);
    fn get_krc_contract(self: @CS) -> ContractAddress;
}

// Data structures
#[derive(Drop, Serde, starknet::Store)]
pub struct Proposal {
    pub id: u64,
    pub title: felt252,
    pub description: felt252,
    pub proposal_type: felt252, // e.g: 'feature' or 'governance'
    pub proposer: ContractAddress,
    pub start_time: u64,
    pub end_time: u64,
    pub for_votes: u256,
    pub against_votes: u256,
    pub executed: bool,
    pub created_at: u64,
}

// Contract implementation
#[starknet::contract]
pub mod KRCPrivilegeManager {
    use OwnableComponent::InternalTrait;
    use core::integer::u256;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::{ContractAddress, EventEmitter, Proposal, get_block_timestamp, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PrivilegeAccessGranted: PrivilegeAccessGranted,
        PrivilegeAccessRevoked: PrivilegeAccessRevoked,
        PrivilegeLevelUpdated: PrivilegeLevelUpdated,
        ProposalCreated: ProposalCreated,
        VoteCast: VoteCast,
        ProposalExecuted: ProposalExecuted,
        KRCContractSet: KRCContractSet,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivilegeAccessGranted {
        pub user: ContractAddress,
        pub feature: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivilegeAccessRevoked {
        pub user: ContractAddress,
        pub feature: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivilegeLevelUpdated {
        pub user: ContractAddress,
        pub level: u8,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalCreated {
        pub proposal_id: u64,
        pub proposer: ContractAddress,
        pub title: felt252,
        pub description: felt252,
        pub proposal_type: felt252,
        pub start_time: u64,
        pub end_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VoteCast {
        pub user: ContractAddress,
        pub proposal_id: u64,
        pub support: bool,
        pub votes: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalExecuted {
        pub proposal_id: u64,
        pub proposal_type: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct KRCContractSet {
        pub krc_contract: ContractAddress,
        pub timestamp: u64,
    }

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // KRC contract address
        krc_contract: ContractAddress,
        // User privileges: user -> feature -> has_access
        user_privileges: Map<(ContractAddress, felt252), bool>,
        user_privilege_levels: Map<ContractAddress, u8>,
        // Proposals
        proposals: Map<u64, bool>,
        proposal_titles: Map<u64, felt252>,
        proposal_descriptions: Map<u64, felt252>,
        proposal_types: Map<u64, felt252>,
        proposal_proposers: Map<u64, ContractAddress>,
        proposal_start_times: Map<u64, u64>,
        proposal_end_times: Map<u64, u64>,
        proposal_for_votes: Map<u64, u256>,
        proposal_against_votes: Map<u64, u256>,
        proposal_executed: Map<u64, bool>,
        proposal_created_at: Map<u64, u64>,
        // Voting tracking
        has_voted: Map<(ContractAddress, u64), bool>,
        next_proposal_id: u64,
        // Constants
        min_voting_balance: u256,
        min_proposal_duration: u64,
        max_proposal_duration: u64,
    }

    // Constructor
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize Ownable
        self.ownable.initializer(owner);

        // Set constants
        self.min_voting_balance.write(1000000000000000000000); // 1K KRC
        self.min_proposal_duration.write(86400); // 1 day
        self.max_proposal_duration.write(604800); // 7 days

        // Initialize proposal counter
        self.next_proposal_id.write(1);
    }

    // Modifiers
    fn only_owner(self: @ContractState) {
        self.ownable.assert_only_owner();
    }

    fn only_krc_holder(self: @ContractState) {
        let caller = get_caller_address();
        let krc_contract = self.krc_contract.read();
        assert(krc_contract != zero_address(), 'KRC contract not set');

        let krc_dispatcher = IERC20Dispatcher { contract_address: krc_contract };
        let balance = krc_dispatcher.balance_of(caller);
        let min_balance = self.min_voting_balance.read();
        assert(balance >= min_balance, 'Insufficient KRC balance');
    }

    fn valid_proposal_duration(self: @ContractState, duration: u64) {
        let min_duration = self.min_proposal_duration.read();
        let max_duration = self.max_proposal_duration.read();
        assert(duration >= min_duration, 'Duration too short');
        assert(duration <= max_duration, 'Duration too long');
    }

    fn zero_address() -> ContractAddress {
        let zero: felt252 = 0;
        zero.try_into().unwrap()
    }

    // Implementation
    #[abi(embed_v0)]
    impl IKRCPrivilegeManagerImpl of super::IKRCPrivilegeManager<ContractState> {
        fn grant_privilege_access(
            ref self: ContractState, user: ContractAddress, feature: felt252,
        ) {
            only_owner(@self);

            self.user_privileges.write((user, feature), true);

            let timestamp = get_block_timestamp();
            self.emit(PrivilegeAccessGranted { user, feature, timestamp });
        }

        fn revoke_privilege_access(
            ref self: ContractState, user: ContractAddress, feature: felt252,
        ) {
            only_owner(@self);

            self.user_privileges.write((user, feature), false);

            let timestamp = get_block_timestamp();
            self.emit(PrivilegeAccessRevoked { user, feature, timestamp });
        }

        fn has_privilege_access(
            self: @ContractState, user: ContractAddress, feature: felt252,
        ) -> bool {
            self.user_privileges.read((user, feature))
        }

        fn get_user_privileges(self: @ContractState, user: ContractAddress) -> Array<felt252> {
            // This is a simplified version - in practice, you'd need to iterate through all
            // possible features For now, return empty array as this would require more complex
            // storage patterns
            let mut privileges = ArrayTrait::new();
            privileges
        }

        fn create_proposal(
            ref self: ContractState,
            title: felt252,
            description: felt252,
            proposal_type: felt252,
            duration: u64,
        ) {
            only_krc_holder(@self);
            valid_proposal_duration(@self, duration);

            let caller = get_caller_address();
            let proposal_id = self.next_proposal_id.read();
            let timestamp = get_block_timestamp();
            let start_time = timestamp; // Start voting immediately
            let end_time = start_time + duration;

            self.proposals.write(proposal_id, true);
            self.proposal_titles.write(proposal_id, title);
            self.proposal_descriptions.write(proposal_id, description);
            self.proposal_types.write(proposal_id, proposal_type);
            self.proposal_proposers.write(proposal_id, caller);
            self.proposal_start_times.write(proposal_id, start_time);
            self.proposal_end_times.write(proposal_id, end_time);
            self.proposal_for_votes.write(proposal_id, 0);
            self.proposal_against_votes.write(proposal_id, 0);
            self.proposal_executed.write(proposal_id, false);
            self.proposal_created_at.write(proposal_id, timestamp);

            self.next_proposal_id.write(proposal_id + 1);

            self
                .emit(
                    ProposalCreated {
                        proposal_id,
                        proposer: caller,
                        title,
                        description,
                        proposal_type,
                        start_time,
                        end_time,
                    },
                );
        }

        fn vote_on_proposal(ref self: ContractState, proposal_id: u64, support: bool) {
            only_krc_holder(@self);

            let exists = self.proposals.read(proposal_id);
            assert(exists, 'Proposal not found');

            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let start_time = self.proposal_start_times.read(proposal_id);
            let end_time = self.proposal_end_times.read(proposal_id);
            assert(timestamp >= start_time, 'Voting not started');
            assert(timestamp <= end_time, 'Voting period ended');

            let has_voted_before = self.has_voted.read((caller, proposal_id));
            assert(!has_voted_before, 'Already voted');

            // Get KRC balance for voting power
            let krc_contract = self.krc_contract.read();
            let krc_dispatcher = IERC20Dispatcher { contract_address: krc_contract };
            let balance = krc_dispatcher.balance_of(caller);

            self.has_voted.write((caller, proposal_id), true);

            if support {
                let current_for_votes = self.proposal_for_votes.read(proposal_id);
                let new_for_votes = current_for_votes + balance;
                self.proposal_for_votes.write(proposal_id, new_for_votes);
            } else {
                let current_against_votes = self.proposal_against_votes.read(proposal_id);
                let new_against_votes = current_against_votes + balance;
                self.proposal_against_votes.write(proposal_id, new_against_votes);
            }

            self.emit(VoteCast { user: caller, proposal_id, support, votes: balance, timestamp });
        }

        fn execute_proposal(ref self: ContractState, proposal_id: u64) {
            only_owner(@self);

            let exists = self.proposals.read(proposal_id);
            assert(exists, 'Proposal not found');

            let timestamp = get_block_timestamp();
            let end_time = self.proposal_end_times.read(proposal_id);
            assert(timestamp >= end_time, 'Voting period not ended');

            let executed = self.proposal_executed.read(proposal_id);
            assert(!executed, 'Proposal already executed');

            let for_votes = self.proposal_for_votes.read(proposal_id);
            let against_votes = self.proposal_against_votes.read(proposal_id);
            assert(for_votes >= against_votes, 'Proposal did not pass');

            let proposal_type = self.proposal_types.read(proposal_id);
            self.proposal_executed.write(proposal_id, true);

            // Handle different proposal types
            if proposal_type == 'feature' { // Grant privilege access to all KRC holders for the approved feature
            // This is a simplified implementation - in practice, you'd need to track all KRC
            // holders and grant them access to the new feature
            }

            self.emit(ProposalExecuted { proposal_id, proposal_type, timestamp });
        }

        fn get_proposal(self: @ContractState, proposal_id: u64) -> Proposal {
            let exists = self.proposals.read(proposal_id);
            assert(exists, 'Proposal not found');

            Proposal {
                id: proposal_id,
                title: self.proposal_titles.read(proposal_id),
                description: self.proposal_descriptions.read(proposal_id),
                proposal_type: self.proposal_types.read(proposal_id),
                proposer: self.proposal_proposers.read(proposal_id),
                start_time: self.proposal_start_times.read(proposal_id),
                end_time: self.proposal_end_times.read(proposal_id),
                for_votes: self.proposal_for_votes.read(proposal_id),
                against_votes: self.proposal_against_votes.read(proposal_id),
                executed: self.proposal_executed.read(proposal_id),
                created_at: self.proposal_created_at.read(proposal_id),
            }
        }

        fn get_user_votes(self: @ContractState, user: ContractAddress, proposal_id: u64) -> bool {
            self.has_voted.read((user, proposal_id))
        }


        fn update_user_privilege_level(ref self: ContractState, user: ContractAddress, level: u8) {
            only_owner(@self);

            self.user_privilege_levels.write(user, level);

            let timestamp = get_block_timestamp();
            self.emit(PrivilegeLevelUpdated { user, level, timestamp });
        }

        fn get_user_privilege_level(self: @ContractState, user: ContractAddress) -> u8 {
            self.user_privilege_levels.read(user)
        }

        fn set_krc_contract(ref self: ContractState, krc_contract: ContractAddress) {
            only_owner(@self);

            self.krc_contract.write(krc_contract);

            let timestamp = get_block_timestamp();
            self.emit(KRCContractSet { krc_contract, timestamp });
        }

        fn get_krc_contract(self: @ContractState) -> ContractAddress {
            self.krc_contract.read()
        }
    }
}
