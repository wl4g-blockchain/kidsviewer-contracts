use kidsviewer::KRC::{IKRCDispatcher, IKRCDispatcherTrait};
use kidsviewer::KRCPrivilegeManager::{
    IKRCPrivilegeManagerDispatcher, IKRCPrivilegeManagerDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Test Accounts
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn PROPOSER() -> ContractAddress {
    'PROPOSER'.try_into().unwrap()
}

fn VOTER() -> ContractAddress {
    'VOTER'.try_into().unwrap()
}

// util deploy function for KRC
fn __deploy_krc__() -> IKRCDispatcher {
    // declare contract
    let contract_class = declare("KRC").expect('failed to declare').contract_class();

    // serialize constructor args
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);

    // deploy contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // return dispatcher
    IKRCDispatcher { contract_address }
}

// util deploy function for Privilege Manager
fn __deploy_privilege_manager__() -> IKRCPrivilegeManagerDispatcher {
    // declare contract
    let contract_class = declare("KRCPrivilegeManager")
        .expect('failed to declare')
        .contract_class();

    // serialize constructor args
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);

    // deploy contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // return dispatcher
    IKRCPrivilegeManagerDispatcher { contract_address }
}

#[test]
fn test_privilege_access_grant() {
    let krc_dispatcher = __deploy_krc__();
    let privilege_dispatcher = __deploy_privilege_manager__();
    let feature = 'test_feature';

    // Set KRC contract in privilege manager
    start_cheat_caller_address(privilege_dispatcher.contract_address, OWNER());
    privilege_dispatcher.set_krc_contract(krc_dispatcher.contract_address);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Grant privilege access
    start_cheat_caller_address(privilege_dispatcher.contract_address, OWNER());
    privilege_dispatcher.grant_privilege_access(USER(), feature);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Check if user has privilege access
    let has_access = privilege_dispatcher.has_privilege_access(USER(), feature);
    assert(has_access, 'Has access');
}

#[test]
fn test_feature_proposal_creation() {
    let krc_dispatcher = __deploy_krc__();
    let privilege_dispatcher = __deploy_privilege_manager__();
    let title = 'Test Feature';
    let description = 'This is a test feature proposal';
    let duration = 86400; // 1 day

    // Mint some KRC to proposer
    start_cheat_caller_address(krc_dispatcher.contract_address, OWNER());
    krc_dispatcher.mint(PROPOSER(), 2000000000000000000000); // 2000 KRC
    stop_cheat_caller_address(krc_dispatcher.contract_address);

    // Set KRC contract in privilege manager
    start_cheat_caller_address(privilege_dispatcher.contract_address, OWNER());
    privilege_dispatcher.set_krc_contract(krc_dispatcher.contract_address);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Create feature proposal
    start_cheat_caller_address(privilege_dispatcher.contract_address, PROPOSER());
    privilege_dispatcher.create_proposal(title, description, 'feature', duration);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Check if proposal was created
    let proposal = privilege_dispatcher.get_proposal(1);
    assert(proposal.title == title, 'Proposal title should match');
    assert(proposal.description == description, 'Desc match');
    assert(proposal.proposal_type == 'feature', 'Proposal type should match');
    assert(proposal.proposer == PROPOSER(), 'Proposal proposer should match');
}

#[test]
fn test_feature_voting() {
    let krc_dispatcher = __deploy_krc__();
    let privilege_dispatcher = __deploy_privilege_manager__();
    let title = 'Test Feature';
    let description = 'This is a test feature proposal';
    let duration = 86400; // 1 day

    // Mint some KRC to voter
    start_cheat_caller_address(krc_dispatcher.contract_address, OWNER());
    krc_dispatcher.mint(VOTER(), 2000000000000000000000); // 2000 KRC
    stop_cheat_caller_address(krc_dispatcher.contract_address);

    // Set KRC contract in privilege manager
    start_cheat_caller_address(privilege_dispatcher.contract_address, OWNER());
    privilege_dispatcher.set_krc_contract(krc_dispatcher.contract_address);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Create feature proposal
    start_cheat_caller_address(privilege_dispatcher.contract_address, VOTER());
    privilege_dispatcher.create_proposal(title, description, 'feature', duration);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Vote on the proposal
    start_cheat_caller_address(privilege_dispatcher.contract_address, VOTER());
    privilege_dispatcher.vote_on_proposal(1, true);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Check if user voted
    let has_voted = privilege_dispatcher.get_user_votes(VOTER(), 1);
    assert(has_voted, 'User should have voted');
}

#[test]
fn test_governance_proposal_creation() {
    let krc_dispatcher = __deploy_krc__();
    let privilege_dispatcher = __deploy_privilege_manager__();
    let title = 'Governance Proposal';
    let description = 'This is a governance proposal';
    let duration = 86400; // 1 day

    // Mint some KRC to proposer
    start_cheat_caller_address(krc_dispatcher.contract_address, OWNER());
    krc_dispatcher.mint(PROPOSER(), 2000000000000000000000); // 2000 KRC
    stop_cheat_caller_address(krc_dispatcher.contract_address);

    // Set KRC contract in privilege manager
    start_cheat_caller_address(privilege_dispatcher.contract_address, OWNER());
    privilege_dispatcher.set_krc_contract(krc_dispatcher.contract_address);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Create governance proposal
    start_cheat_caller_address(privilege_dispatcher.contract_address, PROPOSER());
    privilege_dispatcher.create_proposal(title, description, 'governance', duration);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Check if proposal was created
    let proposal = privilege_dispatcher.get_proposal(1);
    assert(proposal.title == title, 'Proposal title should match');
    assert(proposal.description == description, 'Desc match');
    assert(proposal.proposal_type == 'governance', 'Proposal type should match');
    assert(proposal.proposer == PROPOSER(), 'Proposal proposer should match');
}

#[test]
fn test_governance_voting() {
    let krc_dispatcher = __deploy_krc__();
    let privilege_dispatcher = __deploy_privilege_manager__();
    let title = 'Governance Proposal';
    let description = 'This is a governance proposal';
    let duration = 86400; // 1 day

    // Mint some KRC to voter
    start_cheat_caller_address(krc_dispatcher.contract_address, OWNER());
    krc_dispatcher.mint(VOTER(), 2000000000000000000000); // 2000 KRC
    stop_cheat_caller_address(krc_dispatcher.contract_address);

    // Set KRC contract in privilege manager
    start_cheat_caller_address(privilege_dispatcher.contract_address, OWNER());
    privilege_dispatcher.set_krc_contract(krc_dispatcher.contract_address);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Create governance proposal
    start_cheat_caller_address(privilege_dispatcher.contract_address, VOTER());
    privilege_dispatcher.create_proposal(title, description, 'governance', duration);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Vote on the governance proposal
    start_cheat_caller_address(privilege_dispatcher.contract_address, VOTER());
    privilege_dispatcher.vote_on_proposal(1, true);
    stop_cheat_caller_address(privilege_dispatcher.contract_address);

    // Check if proposal was created and voted on
    let proposal = privilege_dispatcher.get_proposal(1);
    assert(proposal.title == title, 'Proposal title should match');
    assert(proposal.proposal_type == 'governance', 'Proposal type should match');
    assert(proposal.for_votes > 0, 'Proposal should have votes');
}
