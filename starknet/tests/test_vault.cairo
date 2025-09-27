use kidsviewer::KidsViewerVault::{IKidsViewerVaultDispatcher, IKidsViewerVaultDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Test Accounts
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

// Get the actual owner from the deployed contract
fn get_contract_owner(vault_dispatcher: IKidsViewerVaultDispatcher) -> ContractAddress {
    vault_dispatcher.get_owner()
}

fn PARENT() -> ContractAddress {
    'PARENT'.try_into().unwrap()
}

fn CHILD() -> ContractAddress {
    'CHILD'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn TOKEN() -> ContractAddress {
    'TOKEN'.try_into().unwrap()
}

// Constants
const MAX_DAILY_LIMIT: u256 = 10000000000000000000000_u256; // 10K tokens
const MIN_DAILY_LIMIT: u256 = 1000000000000000000000_u256; // 1K tokens

// util deploy function
fn __deploy__() -> IKidsViewerVaultDispatcher {
    // declare contract
    let contract_class = declare("KidsViewerVault").expect('failed to declare').contract_class();

    // serialize constructor args
    let mut calldata: Array<felt252> = array![];
    MAX_DAILY_LIMIT.serialize(ref calldata);
    MIN_DAILY_LIMIT.serialize(ref calldata);

    // deploy contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // return dispatcher
    IKidsViewerVaultDispatcher { contract_address }
}

#[test]
fn test_initial_state() {
    let vault_dispatcher = __deploy__();

    // Check initial state
    let is_paused = vault_dispatcher.paused();
    let max_limit = vault_dispatcher.max_daily_limit();
    let min_limit = vault_dispatcher.min_daily_limit();

    assert(!is_paused, 'Not paused');
    assert(max_limit == MAX_DAILY_LIMIT, 'Max daily limit should match');
    assert(min_limit == MIN_DAILY_LIMIT, 'Min daily limit should match');
}

#[test]
fn test_add_supported_token() {
    let vault_dispatcher = __deploy__();
    let actual_owner = get_contract_owner(vault_dispatcher);

    // Add supported token
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check if token is supported
    let is_supported = vault_dispatcher.supported_tokens(TOKEN());
    assert(is_supported, 'Token should be supported');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_add_supported_token_reverts_when_not_owner() {
    let vault_dispatcher = __deploy__();

    // Try to add token as non-owner
    start_cheat_caller_address(vault_dispatcher.contract_address, USER());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_register_parent() {
    let vault_dispatcher = __deploy__();

    // Register parent
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check if parent is active
    let is_active = vault_dispatcher.parent_active(PARENT());
    assert(is_active, 'Parent should be active');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_register_parent_reverts_when_not_owner() {
    let vault_dispatcher = __deploy__();

    // Try to register parent as non-owner
    start_cheat_caller_address(vault_dispatcher.contract_address, USER());
    vault_dispatcher.register_parent(PARENT());
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_authorize_child() {
    let vault_dispatcher = __deploy__();

    // Register parent
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Authorize child
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.authorize_child(CHILD(), true);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check if child is authorized
    let is_authorized = vault_dispatcher.parent_children(PARENT(), CHILD());
    assert(is_authorized, 'Child should be authorized');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_authorize_child_reverts_when_not_parent() {
    let vault_dispatcher = __deploy__();

    // Try to authorize child as non-parent
    start_cheat_caller_address(vault_dispatcher.contract_address, USER());
    vault_dispatcher.authorize_child(CHILD(), true);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_set_daily_reward_limit() {
    let vault_dispatcher = __deploy__();
    let daily_limit = 5000000000000000000000_u256; // 5K tokens

    // Setup: register parent, authorize child, add token
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.authorize_child(CHILD(), true);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Set daily reward limit
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.set_daily_reward_limit(CHILD(), TOKEN(), daily_limit);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check if limit was set
    let limit = vault_dispatcher.child_daily_limit(CHILD());
    assert(limit == daily_limit, 'Daily limit should be set');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_set_daily_reward_limit_reverts_when_not_parent() {
    let vault_dispatcher = __deploy__();
    let daily_limit = 5000000000000000000000_u256;

    // Try to set limit as non-parent
    start_cheat_caller_address(vault_dispatcher.contract_address, USER());
    vault_dispatcher.set_daily_reward_limit(CHILD(), TOKEN(), daily_limit);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_deposit() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256; // 1K tokens

    // Setup: register parent, add token
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Deposit
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check balance
    let balance = vault_dispatcher.parent_balances(PARENT(), TOKEN());
    let total_balance = vault_dispatcher.total_vault_balances(TOKEN());
    assert(balance == amount, 'Balance match');
    assert(total_balance == amount, 'Total match');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_deposit_reverts_when_not_parent() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Try to deposit as non-parent
    start_cheat_caller_address(vault_dispatcher.contract_address, USER());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Token not supported',))]
fn test_deposit_reverts_when_token_not_supported() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Register parent but don't add token
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Try to deposit unsupported token
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Amount > 0',))]
fn test_deposit_reverts_when_amount_zero() {
    let vault_dispatcher = __deploy__();

    // Setup
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Try to deposit zero amount
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), 0);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Paused',))]
fn test_deposit_reverts_when_paused() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    vault_dispatcher.pause();
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Try to deposit when paused
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_withdraw() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup: register parent, add token, deposit
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Withdraw
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.withdraw(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check balance
    let balance = vault_dispatcher.parent_balances(PARENT(), TOKEN());
    let total_balance = vault_dispatcher.total_vault_balances(TOKEN());
    assert(balance == 0, 'Balance zero');
    assert(total_balance == 0, 'Total zero');
}

#[test]
#[should_panic(expected: ('Insufficient',))]
fn test_withdraw_reverts_when_insufficient_balance() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup: register parent, add token
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Try to withdraw without depositing
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.withdraw(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_distribute_reward() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup: register parent, authorize child, add token, set limit, deposit
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.authorize_child(CHILD(), true);
    vault_dispatcher.set_daily_reward_limit(CHILD(), TOKEN(), MAX_DAILY_LIMIT);
    vault_dispatcher.deposit(TOKEN(), amount);
    vault_dispatcher.set_child_active(CHILD(), true);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Distribute reward
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.distribute_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check daily used
    let daily_used = vault_dispatcher.child_daily_used(CHILD());
    assert(daily_used == amount, 'Daily match');
}

#[test]
#[should_panic(expected: ('Child not active',))]
fn test_distribute_reward_reverts_when_child_not_active() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup: register parent, authorize child, add token, set limit, deposit
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.authorize_child(CHILD(), true);
    vault_dispatcher.set_daily_reward_limit(CHILD(), TOKEN(), MAX_DAILY_LIMIT);
    vault_dispatcher.deposit(TOKEN(), amount);
    // Don't activate child
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Try to distribute reward to inactive child
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.distribute_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);
}

#[test]
fn test_pause() {
    let vault_dispatcher = __deploy__();

    // Pause contract
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.pause();
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check if paused
    let is_paused = vault_dispatcher.paused();
    assert(is_paused, 'Contract should be paused');
}

#[test]
fn test_unpause() {
    let vault_dispatcher = __deploy__();

    // Pause then unpause
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.pause();
    vault_dispatcher.unpause();
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check if unpaused
    let is_paused = vault_dispatcher.paused();
    assert(!is_paused, 'Contract should be unpaused');
}

#[test]
fn test_get_parent_balance() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup and deposit
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check parent balance
    let balance = vault_dispatcher.get_parent_balance(PARENT(), TOKEN());
    assert(balance == amount, 'Balance match');
}

#[test]
fn test_get_child_config() {
    let vault_dispatcher = __deploy__();
    let daily_limit = 5000000000000000000000_u256;

    // Setup
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.authorize_child(CHILD(), true);
    vault_dispatcher.set_daily_reward_limit(CHILD(), TOKEN(), daily_limit);
    vault_dispatcher.set_child_active(CHILD(), true);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Get child config
    let (daily_reward_limit, daily_reward_used, _last_reset_date, is_active) = vault_dispatcher
        .get_child_config(CHILD());
    assert(daily_reward_limit == daily_limit, 'Daily limit should match');
    assert(daily_reward_used == 0, 'Daily zero');
    assert(is_active, 'Child should be active');
}

#[test]
fn test_is_parent_authorized() {
    let vault_dispatcher = __deploy__();

    // Register parent
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Initially not authorized
    let is_authorized = vault_dispatcher.is_parent_authorized(PARENT(), CHILD());
    assert(!is_authorized, 'Not authorized');

    // Authorize child
    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.authorize_child(CHILD(), true);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Now authorized
    let is_authorized = vault_dispatcher.is_parent_authorized(PARENT(), CHILD());
    assert(is_authorized, 'Authorized');
}

#[test]
fn test_get_total_vault_balance() {
    let vault_dispatcher = __deploy__();
    let amount = 1000000000000000000000_u256;

    // Setup and deposit
    let actual_owner = get_contract_owner(vault_dispatcher);
    start_cheat_caller_address(vault_dispatcher.contract_address, actual_owner);
    vault_dispatcher.register_parent(PARENT());
    vault_dispatcher.add_supported_token(TOKEN());
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    start_cheat_caller_address(vault_dispatcher.contract_address, PARENT());
    vault_dispatcher.deposit(TOKEN(), amount);
    stop_cheat_caller_address(vault_dispatcher.contract_address);

    // Check total vault balance
    let total_balance = vault_dispatcher.get_total_vault_balance(TOKEN());
    assert(total_balance == amount, 'Total match');
}
