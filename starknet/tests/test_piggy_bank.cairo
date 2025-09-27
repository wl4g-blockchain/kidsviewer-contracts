use kidsviewer::KidsViewerPiggyBank::{
    IKidsViewerPiggyBankDispatcher, IKidsViewerPiggyBankDispatcherTrait,
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

// Get the actual owner from the deployed contract
fn get_contract_owner(piggy_bank_dispatcher: IKidsViewerPiggyBankDispatcher) -> ContractAddress {
    piggy_bank_dispatcher.owner()
}

fn PARENT() -> ContractAddress {
    'PARENT'.try_into().unwrap()
}

fn CHILD() -> u64 {
    1
}

fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn TOKEN() -> ContractAddress {
    'TOKEN'.try_into().unwrap()
}

fn AAVE_PRODUCT() -> ContractAddress {
    'AAVE_PRODUCT'.try_into().unwrap()
}

// util deploy function
fn __deploy__() -> IKidsViewerPiggyBankDispatcher {
    // declare contract
    let contract_class = declare("KidsViewerPiggyBank")
        .expect('failed to declare')
        .contract_class();

    // serialize constructor args
    let mut calldata: Array<felt252> = array![];

    // deploy contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // return dispatcher
    IKidsViewerPiggyBankDispatcher { contract_address }
}

#[test]
fn test_initial_state() {
    let piggy_bank_dispatcher = __deploy__();

    // Check initial state
    let is_paused = piggy_bank_dispatcher.paused();
    let next_request_id = piggy_bank_dispatcher.next_request_id();

    assert(!is_paused, 'Not paused');
    assert(next_request_id == 1, 'Next request ID should be 1');
}

#[test]
fn test_receive_reward() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 1000000000000000000000; // 1K tokens

    // Setup: parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Receive reward
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check balances
    let child_balance = piggy_bank_dispatcher.person_balances(CHILD(), TOKEN());
    let person_earnings = piggy_bank_dispatcher.person_earnings(CHILD(), TOKEN());
    assert(child_balance == amount, 'Balance match');
    assert(person_earnings == amount, 'Earnings match');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_receive_reward_reverts_when_not_parent() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 1000000000000000000000;

    // Try to receive reward as non-parent
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, USER());
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Paused',))]
fn test_receive_reward_reverts_when_paused() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 1000000000000000000000;

    // Setup: parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Pause contract
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.pause();
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Try to receive reward when paused
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Amount > 0',))]
fn test_receive_reward_reverts_when_amount_zero() {
    let piggy_bank_dispatcher = __deploy__();

    // Setup: parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Try to receive zero amount
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 0);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_request_withdrawal() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000; // 500 tokens
    let reason = 'Need money for school supplies';

    // Setup: parent approval and child balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Request withdrawal
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check request
    let request_id = piggy_bank_dispatcher.person_request_ids(CHILD());
    let (child, token, amount_val, reason_val, approved, executed, _) = piggy_bank_dispatcher
        .get_withdrawal_request(request_id);
    assert(child == CHILD(), 'Request child should match');
    assert(token == TOKEN(), 'Request token should match');
    assert(amount_val == amount, 'Request amount should match');
    assert(reason_val == reason, 'Reason match');
    assert(!approved, 'Not approved');
    assert(!executed, 'Not executed');
}

#[test]
#[should_panic(expected: ('Insufficient',))]
fn test_request_withdrawal_reverts_when_insufficient_balance() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';

    // Try to request withdrawal without balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Paused',))]
fn test_request_withdrawal_reverts_when_paused() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';

    // Pause contract
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.pause();
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Try to request withdrawal when paused
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Amount > 0',))]
fn test_request_withdrawal_reverts_when_amount_zero() {
    let piggy_bank_dispatcher = __deploy__();
    let reason = 'Need money for school supplies';

    // Try to request zero amount
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), 0, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_approve_withdrawal() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';

    // Setup: parent approval and child balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Request withdrawal
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Approve withdrawal
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.approve_withdrawal(1);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check request and balance
    let (_, _, _, _, approved, _, _) = piggy_bank_dispatcher.get_withdrawal_request(1);
    let child_balance = piggy_bank_dispatcher.person_balances(CHILD(), TOKEN());
    assert(approved, 'Request should be approved');
    assert(child_balance == 1000000000000000000000 - amount, 'Child balance should be reduced');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_approve_withdrawal_reverts_when_not_owner() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';

    // Setup
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Try to approve as non-owner
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.approve_withdrawal(1);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_reject_withdrawal() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';
    let rejection_reason = 'Not a valid reason';

    // Setup
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Reject withdrawal
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.reject_withdrawal(1, rejection_reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check request
    let (_, _, _, reason_val, approved, executed, _) = piggy_bank_dispatcher
        .get_withdrawal_request(1);
    assert(!approved, 'Request should not be approved');
    assert(executed, 'Executed');
    assert(reason_val == rejection_reason, 'Reason updated');
}

#[test]
fn test_invest_in_aave() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;

    // Setup: parent approval and child balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Invest in AAVE
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.invest_in_aave(CHILD(), TOKEN(), amount, AAVE_PRODUCT());
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check balance
    let child_balance = piggy_bank_dispatcher.person_balances(CHILD(), TOKEN());
    assert(child_balance == 1000000000000000000000 - amount, 'Child balance should be reduced');
}

#[test]
#[should_panic(expected: ('Insufficient',))]
fn test_invest_in_aave_reverts_when_insufficient_balance() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;

    // Setup: parent approval but no balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Try to invest without balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.invest_in_aave(CHILD(), TOKEN(), amount, AAVE_PRODUCT());
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Paused',))]
fn test_invest_in_aave_reverts_when_paused() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;

    // Pause contract
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.pause();
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Try to invest when paused
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.invest_in_aave(CHILD(), TOKEN(), amount, AAVE_PRODUCT());
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('Amount > 0',))]
fn test_invest_in_aave_reverts_when_amount_zero() {
    let piggy_bank_dispatcher = __deploy__();

    // Try to invest zero amount
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.invest_in_aave(CHILD(), TOKEN(), 0, AAVE_PRODUCT());
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_recover_all_investments() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;

    // Setup: parent approval and child balance
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Recover investments
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.recover_all_investments(CHILD(), TOKEN());
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check balance
    let child_balance = piggy_bank_dispatcher.person_balances(CHILD(), TOKEN());
    assert(child_balance == 0, 'Balance zero');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_recover_all_investments_reverts_when_not_parent() {
    let piggy_bank_dispatcher = __deploy__();

    // Try to recover as non-parent
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, USER());
    piggy_bank_dispatcher.recover_all_investments(CHILD(), TOKEN());
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_set_parent_approval() {
    let piggy_bank_dispatcher = __deploy__();

    // Set parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check approval
    let is_approved = piggy_bank_dispatcher.parent_approvals(PARENT(), CHILD());
    assert(is_approved, 'Parent should be approved');
}

#[test]
fn test_set_investment_config() {
    let piggy_bank_dispatcher = __deploy__();
    let enabled = true;
    let max_amount = 10000000000000000000000; // 10K tokens

    // Setup: parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Set investment config
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_investment_config(CHILD(), enabled, max_amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check config
    let (is_enabled, max_investment_amount, total_invested) = piggy_bank_dispatcher
        .get_investment_config(CHILD());
    assert(is_enabled == enabled, 'Investment should be enabled');
    assert(max_investment_amount == max_amount, 'Max amount should match');
    assert(total_invested == 0, 'Total zero');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_set_investment_config_reverts_when_not_parent() {
    let piggy_bank_dispatcher = __deploy__();
    let enabled = true;
    let max_amount = 10000000000000000000000;

    // Try to set config as non-parent
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, USER());
    piggy_bank_dispatcher.set_investment_config(CHILD(), enabled, max_amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_set_aave_product_approval() {
    let piggy_bank_dispatcher = __deploy__();
    let approved = true;

    // Setup: parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Set AAVE product approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_aave_product_approval(CHILD(), AAVE_PRODUCT(), approved);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check approval
    let is_approved = piggy_bank_dispatcher.aave_product_approvals(CHILD(), AAVE_PRODUCT());
    assert(is_approved, 'AAVE product should be approved');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_set_aave_product_approval_reverts_when_not_parent() {
    let piggy_bank_dispatcher = __deploy__();
    let approved = true;

    // Try to set approval as non-parent
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, USER());
    piggy_bank_dispatcher.set_aave_product_approval(CHILD(), AAVE_PRODUCT(), approved);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_set_person_active() {
    let piggy_bank_dispatcher = __deploy__();

    // Set child active
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.set_person_active(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check if active
    let is_active = piggy_bank_dispatcher.person_active(CHILD());
    assert(is_active, 'Child should be active');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_person_active_reverts_when_not_owner() {
    let piggy_bank_dispatcher = __deploy__();

    // Try to set child active as non-owner
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, USER());
    piggy_bank_dispatcher.set_person_active(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);
}

#[test]
fn test_pause() {
    let piggy_bank_dispatcher = __deploy__();

    // Pause contract
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.pause();
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check if paused
    let is_paused = piggy_bank_dispatcher.paused();
    assert(is_paused, 'Contract should be paused');
}

#[test]
fn test_unpause() {
    let piggy_bank_dispatcher = __deploy__();

    // Pause then unpause
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.pause();
    piggy_bank_dispatcher.unpause();
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check if unpaused
    let is_paused = piggy_bank_dispatcher.paused();
    assert(!is_paused, 'Contract should be unpaused');
}

#[test]
fn test_get_person_balance() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 1000000000000000000000;

    // Setup and receive reward
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check child balance
    let balance = piggy_bank_dispatcher.get_person_balance(CHILD(), TOKEN());
    assert(balance == amount, 'Balance match');
}

#[test]
fn test_get_person_earnings() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 1000000000000000000000;

    // Setup and receive reward
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), amount);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Check child earnings
    let (balance, earnings) = piggy_bank_dispatcher.get_person_earnings(CHILD(), TOKEN());
    assert(balance == amount, 'Balance match');
    assert(earnings == amount, 'Earnings match');
}

#[test]
fn test_get_withdrawal_request() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';

    // Setup and request withdrawal
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Get withdrawal request
    let (child, token, amount_val, reason_val, _, _, _) = piggy_bank_dispatcher
        .get_withdrawal_request(1);
    assert(child == CHILD(), 'Request child should match');
    assert(token == TOKEN(), 'Request token should match');
    assert(amount_val == amount, 'Request amount should match');
    assert(reason_val == reason, 'Reason match');
}

#[test]
fn test_get_person_withdrawal_requests() {
    let piggy_bank_dispatcher = __deploy__();
    let amount = 500000000000000000000;
    let reason = 'Need money for school supplies';

    // Setup and request withdrawal
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    piggy_bank_dispatcher.receive_reward(CHILD(), TOKEN(), 1000000000000000000000);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.request_withdrawal(CHILD(), TOKEN(), amount, reason);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Get child withdrawal requests
    let request_id = piggy_bank_dispatcher.get_person_withdrawal_requests(CHILD());
    assert(request_id == 1, 'Request ID should be 1');
}

#[test]
fn test_is_aave_product_approved() {
    let piggy_bank_dispatcher = __deploy__();

    // Setup: parent approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Initially not approved
    let is_approved = piggy_bank_dispatcher.is_aave_product_approved(CHILD(), AAVE_PRODUCT());
    assert(!is_approved, 'Not approved');

    // Set approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_aave_product_approval(CHILD(), AAVE_PRODUCT(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Now approved
    let is_approved = piggy_bank_dispatcher.is_aave_product_approved(CHILD(), AAVE_PRODUCT());
    assert(is_approved, 'AAVE product should be approved');
}

#[test]
fn test_is_parent_approved() {
    let piggy_bank_dispatcher = __deploy__();

    // Initially not approved
    let is_approved = piggy_bank_dispatcher.is_parent_approved(PARENT(), CHILD());
    assert(!is_approved, 'Not approved');

    // Set approval
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, PARENT());
    piggy_bank_dispatcher.set_parent_approval(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Now approved
    let is_approved = piggy_bank_dispatcher.is_parent_approved(PARENT(), CHILD());
    assert(is_approved, 'Parent should be approved');
}

#[test]
fn test_is_person_active() {
    let piggy_bank_dispatcher = __deploy__();

    // Initially not active
    let is_active = piggy_bank_dispatcher.is_person_active(CHILD());
    assert(!is_active, 'Not active');

    // Set active
    let actual_owner = get_contract_owner(piggy_bank_dispatcher);
    start_cheat_caller_address(piggy_bank_dispatcher.contract_address, actual_owner);
    piggy_bank_dispatcher.set_person_active(CHILD(), true);
    stop_cheat_caller_address(piggy_bank_dispatcher.contract_address);

    // Now active
    let is_active = piggy_bank_dispatcher.is_person_active(CHILD());
    assert(is_active, 'Child should be active');
}
