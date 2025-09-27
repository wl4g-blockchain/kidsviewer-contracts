// // SPDX-License-Identifier: MIT
// %lang starknet

// from starknet.std import (
//     get_caller_address, get_block_timestamp, get_contract_address,
//     assert_le, assert_ge, assert_eq, assert_not_zero, assert_not_equal
// )

// // Storage for reentrancy guards
// @storage
// struct Storage {
//     task_guards: Map<felt, felt>;  // task_id => is_locked
// }

// // Modifier for non-reentrant calls
// func non_reentrant{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     task_id: felt
// ) {
//     let (is_locked) = task_guards.read(task_id);
//     assert_eq(is_locked, 0, "ReentrancyGuard: reentrant call");
//     task_guards.write(task_id, 1);
// }

// // Function to release the guard (should be called at the end of protected functions)
// func release_guard{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     task_id: felt
// ) {
//     task_guards.write(task_id, 0);
// }

// // View function to check if a task is locked
// @view
// func is_task_locked{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     task_id: felt
// ) -> (locked: felt) {
//     let (locked) = task_guards.read(task_id);
//     return (locked,);
// }