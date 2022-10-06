%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.bool import TRUE, FALSE

const NORMAL = 1;
const QUADRATIC = 2;

//id'yi sıfırlayınca o numarayı bir arraye koyup ileride gelen bir kişiye o id'yi vereceğim

//
// STORAGE
//

@storage_var
func user_balance_storage(user_address: felt) -> (user_balance: felt) {
}

@storage_var
func user_id_storage(user_id: felt) -> (user_address: felt) {
}
//could be an array maybe
@storage_var
func idle_ids_storage(index: felt) -> (idle_id: felt) {
}

@storage_var
func last_idle_id_index_storage() -> (last_idle_id_index: felt) {
}

@storage_var
func lottery_staked_balance_storage() -> (total_balance: felt) {
}

//bölerken kalanları en sonuncu protokola atmalı 
@storage_var
func protocol_proportions_storage(protocol_index: felt) -> (proportion_by_100: felt) {
}

@storage_var
func protocol_addresses_storage(protocol_index: felt) -> (protocol_address: felt) {
}

@storage_var
func L1_vrf_bridge_address_storage() -> (contract_address: felt) {
}

//
// CONSTRUCTOR
//


//
// VIEW
//


//
// EXTERNAL
//

@external
func set_protocol_proportions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arguments
) {
    
}

@external
func distribute_reward_in_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
}

// quadratic lottery will be activated when there is a good sybil resistant system in starknet
// people can withdraw an arbitrary amount of usdc

// proportion onemli
// index bosaldiysa ona atamak onemli
@external
func buy_slot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    deposit_amount: felt, lottery_type: felt
) {
  
    with_attr error_message("Quadratic is not enabled") {
        assert lottery_type = 1;
    }
    if (lottery_type == 1) {
        let last_slot = last_assigned_slot.read();
        assign_slots_normal(last_slot + 1, deposit_amount);
    } else {
    }
}

@external
func sell_slot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    withdraw_amount: felt, lottery_type: felt
) {
    
}

@l1_handler
func distribute_with_random{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
}(from_address: felt, random_number: felt){
    let l1_address = L1_vrf_bridge_address_storage.read();

    with_attr error_message("l1 address is not compatible") {
        assert l1_address = from_address;
    }

    let winner_address = distribute_reward(random_number = random_number)
}

@external
func distribute_reward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random_number: felt
) -> (winner: felt) {
    
}

@external
func offer_staking_protocol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arguments
) {
}


