use kidsviewer::KRC::{IKRCDispatcher, IKRCDispatcherTrait, KRC};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::ERC20Component;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// Constants
const INITIAL_SUPPLY: u256 = 10000000000000000000000000_u256; // 10M KRC
const MAX_SUPPLY: u256 = 100000000000000000000000000_u256; // 100M KRC

// Test Accounts
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER_1() -> ContractAddress {
    'USER_1'.try_into().unwrap()
}

fn USER_2() -> ContractAddress {
    'USER_2'.try_into().unwrap()
}

// util deploy function
fn __deploy__() -> (IKRCDispatcher, IOwnableDispatcher) {
    // declare contract
    let contract_class = declare("KRC").expect('failed to declare').contract_class();

    // serialize constructor args
    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);

    // deploy contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // return values
    let krc = IKRCDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    (krc, ownable)
}

#[test]
fn test_initial_state() {
    let (krc, ownable) = __deploy__();

    // Check initial state
    let name = krc.name();
    let symbol = krc.symbol();
    let decimals = krc.decimals();
    let total_supply = krc.total_supply();
    let owner_balance = krc.balance_of(OWNER());
    let is_paused = krc.paused();

    assert(name == "KRC", 'Name should be KRC');
    assert(symbol == "KRC", 'Symbol should be KRC');
    assert(decimals == 18, 'Decimals should be 18');
    assert(total_supply == INITIAL_SUPPLY, 'Total supply should be 10M KRC');
    assert(owner_balance == INITIAL_SUPPLY, 'Owner should have initial');
    assert(!is_paused, 'Contract should not paused init');
    assert(ownable.owner() == OWNER(), 'Owner should be set correctly');
}

#[test]
fn test_mint() {
    let (krc, _) = __deploy__();
    let mint_amount = 1000000000000000000000_u256; // 1000 KRC

    // Mint tokens to user
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), mint_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Check balances
    let user_balance = krc.balance_of(USER_1());
    let total_supply = krc.total_supply();

    assert(user_balance == mint_amount, 'User should have minted amount');
    assert(total_supply == INITIAL_SUPPLY + mint_amount, 'Total supply should increase');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_reverts_when_not_owner() {
    let (krc, _) = __deploy__();
    let mint_amount = 1000000000000000000000_u256; // 1000 KRC

    // Try to mint as non-owner
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.mint(USER_1(), mint_amount);
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
#[should_panic(expected: ('Exceeds max supply',))]
fn test_mint_reverts_when_exceeds_max_supply() {
    let (krc, _) = __deploy__();
    let mint_amount = 100000000000000000000000000_u256; // 100M KRC (exceeds max supply)

    // Try to mint more than max supply
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), mint_amount);
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
#[should_panic(expected: ('Amount > 0',))]
fn test_mint_reverts_when_amount_zero() {
    let (krc, _) = __deploy__();

    // Try to mint zero amount
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), 0);
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
fn test_burn() {
    let (krc, _) = __deploy__();
    let mint_amount = 1000000000000000000000_u256; // 1000 KRC

    // Mint tokens to user
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), mint_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Burn tokens
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.burn(mint_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Check balances
    let user_balance = krc.balance_of(USER_1());
    let total_supply = krc.total_supply();

    assert(user_balance == 0_u256, 'User balance should be zero');
    assert(total_supply == INITIAL_SUPPLY, 'Total supply should be initial');
}

#[test]
#[should_panic(expected: ('Insufficient',))]
fn test_burn_reverts_when_insufficient_balance() {
    let (krc, _) = __deploy__();
    let burn_amount = 1000000000000000000000_u256; // 1000 KRC

    // Try to burn without having tokens
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.burn(burn_amount);
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
#[should_panic(expected: ('Amount > 0',))]
fn test_burn_reverts_when_amount_zero() {
    let (krc, _) = __deploy__();

    // Try to burn zero amount
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.burn(0);
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
fn test_pause() {
    let (krc, _) = __deploy__();

    // Pause contract
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.pause();
    stop_cheat_caller_address(krc.contract_address);

    // Check if paused
    let is_paused = krc.paused();
    assert(is_paused, 'Contract should be paused');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_pause_reverts_when_not_owner() {
    let (krc, _) = __deploy__();

    // Try to pause as non-owner
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.pause();
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
fn test_unpause() {
    let (krc, _) = __deploy__();

    // Pause contract
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.pause();
    stop_cheat_caller_address(krc.contract_address);

    // Unpause contract
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.unpause();
    stop_cheat_caller_address(krc.contract_address);

    // Check if unpaused
    let is_paused = krc.paused();
    assert(!is_paused, 'Contract should be unpaused');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_unpause_reverts_when_not_owner() {
    let (krc, _) = __deploy__();

    // Try to unpause as non-owner
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.unpause();
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
#[should_panic(expected: ('Paused',))]
fn test_transfer_reverts_when_paused() {
    let (krc, _) = __deploy__();
    let transfer_amount = 1000000000000000000000_u256; // 1000 KRC

    // Mint tokens to user1
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), transfer_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Pause contract
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.pause();
    stop_cheat_caller_address(krc.contract_address);

    // Try to transfer while paused
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.transfer(USER_2(), transfer_amount);
    stop_cheat_caller_address(krc.contract_address);
}

#[test]
fn test_transfer_works_when_not_paused() {
    let (krc, _) = __deploy__();
    let transfer_amount = 1000000000000000000000_u256; // 1000 KRC

    // Mint tokens to user1
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), transfer_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Transfer should work
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.transfer(USER_2(), transfer_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Check balances
    let user1_balance = krc.balance_of(USER_1());
    let user2_balance = krc.balance_of(USER_2());

    assert(user1_balance == 0_u256, 'User1 balance should be zero');
    assert(user2_balance == transfer_amount, 'User2 should have amount');
}

#[test]
fn test_constants() {
    let (krc, _) = __deploy__();

    // Check constants
    let max_supply = krc.max_supply();
    let initial_supply = krc.initial_supply();

    assert(max_supply == MAX_SUPPLY, 'Max supply should be 100M KRC');
    assert(initial_supply == INITIAL_SUPPLY, 'Init supply should be 10M KRC');
}

#[test]
fn test_emitted_transfer_event() {
    let (krc, _) = __deploy__();
    let transfer_amount = 1000000000000000000000_u256; // 1000 KRC

    // Mint tokens to user1
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), transfer_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Create a spy instance to capture and inspect emitted events during the test.
    let mut spy = spy_events();

    // Transfer tokens
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.transfer(USER_2(), transfer_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Check that the correct Transfer event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    krc.contract_address,
                    KRC::Event::ERC20Event(
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: USER_1(), to: USER_2(), value: transfer_amount,
                            },
                        ),
                    ),
                ),
            ],
        );
}

#[test]
fn test_emitted_mint_event() {
    let (krc, _) = __deploy__();
    let mint_amount = 1000000000000000000000_u256; // 1000 KRC

    // Create a spy instance to capture and inspect emitted events during the test.
    let mut spy = spy_events();

    // Mint tokens
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), mint_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Check that the correct Transfer event was emitted for minting
    spy
        .assert_emitted(
            @array![
                (
                    krc.contract_address,
                    KRC::Event::ERC20Event(
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: 0.try_into().unwrap(), to: USER_1(), value: mint_amount,
                            },
                        ),
                    ),
                ),
            ],
        );
}

#[test]
fn test_emitted_burn_event() {
    let (krc, _) = __deploy__();
    let mint_amount = 1000000000000000000000_u256; // 1000 KRC

    // Mint tokens to user1
    start_cheat_caller_address(krc.contract_address, OWNER());
    krc.mint(USER_1(), mint_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Create a spy instance to capture and inspect emitted events during the test.
    let mut spy = spy_events();

    // Burn tokens
    start_cheat_caller_address(krc.contract_address, USER_1());
    krc.burn(mint_amount);
    stop_cheat_caller_address(krc.contract_address);

    // Check that the correct Transfer event was emitted for burning
    spy
        .assert_emitted(
            @array![
                (
                    krc.contract_address,
                    KRC::Event::ERC20Event(
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: USER_1(), to: 0.try_into().unwrap(), value: mint_amount,
                            },
                        ),
                    ),
                ),
            ],
        );
}
