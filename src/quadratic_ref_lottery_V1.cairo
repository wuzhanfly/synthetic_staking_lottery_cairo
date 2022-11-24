%lang starknet

// use this if you can guarantee sybil resistance
from src.interfaces.i_token import IToken
from src.interfaces.i_staking import IStaking
from openzeppelin.access.ownable.library import Ownable
from openzeppelin.security.pausable.library import Pausable

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)

from starkware.cairo.common.math import (
    assert_lt,
    unsigned_div_rem,
    assert_nn,
    assert_le,
    assert_not_equal,
    sqrt,
)
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.bool import TRUE, FALSE

//
// EVENTS
//

@event
func migrated_called(new_contract_address: felt) {
}

//
// STORAGE
//

@storage_var
func user_id_storage(user_id: felt) -> (user_address: felt) {
}

@storage_var
func user_squared_storage(user_address: felt) -> (user_squared_balance: felt) {
}

@storage_var
func user_balance_storage(user_address: felt) -> (user_balance: felt) {
}

@storage_var
func idle_ids_storage(index: felt) -> (idle_id: felt) {
}

@storage_var
func last_idle_id_index_storage() -> (last_idle_id_index: felt) {
}

@storage_var
func user_count_storage() -> (count: felt) {
}

@storage_var
func lottery_staked_balance_storage() -> (total_balance: felt) {
}

// bölerken kalanları en sonuncu protokole atmalı
@storage_var
func pool_proportions_by_100_storage(pool_id: felt) -> (proportion_by_100: felt) {
}

// propu 0 olan yani silinen poollar da duracak burda ama 0 olanlari
// fonklarda atlayacak
@storage_var
func available_pool_id_storage(index: felt) -> (available_ids: felt) {
}

@storage_var
func pool_count_storage() -> (pool_count: felt) {
}

@storage_var
func user_pool_balance_storage(pool_id: felt) -> (balance: felt) {
}

@storage_var
func staking_protocol_address_storage() -> (protocol_address: felt) {
}

@storage_var
func L1_vrf_bridge_address_storage() -> (contract_address: felt) {
}

@storage_var
func stable_token_address_storage() -> (contract_address: felt) {
}

//
// CONSTRUCTOR
// adresi ata, idle_id_storage baslat,protocol index ve adresleri yaz ve oranlari belirle

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    staking_protocol_address: felt,
    stable_token_address: felt,
    L1_vrf_bridge_address: felt,
) {
    Ownable.initializer(owner);
    last_idle_id_index_storage.write(1);
    idle_ids_storage.write(1, 1);  // index starts from 1-1
    staking_protocol_address_storage.write(staking_protocol_address);
    stable_token_address_storage.write(stable_token_address);
    L1_vrf_bridge_address_storage.write(L1_vrf_bridge_address);
    return ();
}

//
// VIEW
//

//
// EXTERNAL
//

// if all protocols had same interfaces it would be much better
// but for now we have to migrate to add new interfaces

// need a loop to withdraw from all existing pool
@external
func migrate_to_new_lottery_contract{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(contract_address: felt) {
    alloc_locals;
    Ownable.assert_only_owner();
    // looks up to balance of contract and withdraw all that amount
    // it will look
    // withdraw_all_funds_to_new_contract(contract_address);
    migrated_called.emit(new_contract_address=contract_address);
    return ();
}

@external
func add_new_pool{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_id: felt, proportion_by_100: felt
) {
    alloc_locals;
    Ownable.assert_only_owner();

    with_attr error_message("Negative proportion") {
        assert_nn(proportion_by_100);
    }

    let (count) = pool_count_storage.read();
    // index starts from 1
    pool_count_storage.write(count + 1);
    pool_proportions_by_100_storage.write(pool_id=pool_id, value=proportion_by_100);
    available_pool_id_storage.write(index=count + 1, value=pool_id);
    return ();
}

// if owner wants to change proportion to 0, he needs to change other proportions to match 100
// if owner wants change all balances on pools, should set proportion 0 first to withdraw all funds
// then redistribute
@external
func change_pool_proportion{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_id: felt, proportion_by_100: felt
) {
    alloc_locals;
    Ownable.assert_only_owner();

    with_attr error_message("Negative proportion") {
        assert_nn(proportion_by_100);
    }

    // to prevent adding new pool
    let (is_zero) = pool_proportions_by_100_storage.read(pool_id=pool_id);

    with_attr error_message("Pool does not exist in lottery contract") {
        assert_not_equal(is_zero, 0);
    }
    // should stay paused until proportions match 100
    pause();
    pool_proportions_by_100_storage.write(pool_id=pool_id, value=proportion_by_100);

    if (proportion_by_100 == 0) {
        let (staking_address) = staking_protocol_address_storage.read();
        let (lottery_address) = get_contract_address();
        let (staked) = IStaking.get_balance_of_staked_token(
            contract_address=staking_address, pair_id=pool_id, user_address=lottery_address
        );
        IStaking.withdraw(contract_address=staking_address, amount=staked, pair_id=pool_id);
        IStaking.get_reward(contract_address=staking_address, pair_id=pool_id);
        return ();
    }

    return ();
}

// if owner wants to send send 0 proportion pools funds to other pools he need to call a function
// that function will withdraw funds and get reward then send funds with add_to_pool_by_proportion

// first control if proportions match 100 and after that call this function as owner
@external
func distribute_zero_pools_fund{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pool_id: felt, proportion_by_100: felt
) {
    alloc_locals;
    Ownable.assert_only_owner();
    Pausable.assert_not_paused();

    let (stable_address) = stable_token_address_storage.read();
    let (lottery_address) = get_contract_address();

    let (balance: Uint256) = IToken.balanceOf(
        contract_address=stable_address, account=lottery_address
    );

    let (count) = pool_count_storage.read();
    // uint to felt conversion, is that good practice?

    add_to_pool_by_proportion(
        deposit_amount=balance.low,
        pool_count=count,
        starter_index=1,
        prop_tracker=0,
        remaining_amount=0,
    );

    return ();
}

// need to call periodically and after that should consume message on L1
@external
func distribute_reward_in_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

// proportion onemli
// index bosaldiysa ona atamak onemli
// USER SHOULD APPROVE FIRST
// suggest to user to deposit perfect square amount or restrict from front end
// only perfect square numbres can be appreciated fully
@external
func buy_slot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    deposit_amount: felt
) {
    alloc_locals;
    Pausable.assert_not_paused();

    with_attr error_message("deposit_amount <= 0") {
        assert_nn(deposit_amount - 1);
    }

    let (staking_address) = staking_protocol_address_storage.read();
    let (stable_address) = stable_token_address_storage.read();
    let (caller) = get_caller_address();
    let (lottery_address) = get_contract_address();

    let uint256_amount: Uint256 = Uint256(deposit_amount, 0);

    IToken.transferFrom(stable_address, caller, lottery_address, uint256_amount);
    IToken.approve(stable_address, staking_address, uint256_amount);
    let (count) = pool_count_storage.read();
    add_to_pool_by_proportion(
        deposit_amount=deposit_amount,
        pool_count=count,
        starter_index=1,
        prop_tracker=0,
        remaining_amount=0,
    );

    let (user_balance) = user_balance_storage.read(user_address=caller);
    let (user_squared_balance) = user_squared_storage.read(user_address=caller);
    // if user has 0 amount on lottery, contract assigns a new id to user if all previous ids are full
    // if there is hole in ids, contract assigns an idle id to user
    if (user_balance == 0) {
        let (user_count) = user_count_storage.read();
        user_count_storage.write(user_count + 1);

        user_balance_storage.write(user_address=caller, value=deposit_amount);
        let (idle_id_index) = last_idle_id_index_storage.read();
        let (idle_id) = idle_ids_storage.read(index=idle_id_index);

        if (idle_id == 0) {
            user_id_storage.write(user_id=user_count + 1, value=caller);
            return ();
        }
        last_idle_id_index_storage.write(idle_id_index + 1);

        user_id_storage.write(user_id=idle_id, value=caller);

        let squared_balance = sqrt(deposit_amount);
        user_squared_storage.write(user_address=caller, value=squared_balance);
        return ();
    } else {
        user_balance_storage.write(user_address=caller, value=user_balance + deposit_amount);
        let squared_balance = sqrt(deposit_amount);
        user_squared_storage.write(
            user_address=caller, value=squared_balance + user_squared_balance
        );
        return ();
    }
}

// while withdraw we can send withdraw amount directly to user
// we should look up to proportion==0 pools also
@external
func sell_slot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    withdraw_amount: felt, lottery_type: felt
) {
    Pausable.assert_not_paused();
    return ();
}

// @external
// func distribute_reward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     random_number: felt
// ) -> (winner: felt) {
//     Pausable.assert_not_paused();
//     return ();
// }

@external
func offer_staking_protocol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}
//
// FUNCS
//

func add_to_pool_by_proportion{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    deposit_amount: felt,
    pool_count: felt,
    starter_index: felt,
    prop_tracker: felt,
    remaining_amount: felt,
) {
    alloc_locals;
    if (pool_count == 0) {
        return ();
    }

    let (available_pool_id) = available_pool_id_storage.read(starter_index);
    let (proportion) = pool_proportions_by_100_storage.read(pool_id=available_pool_id);

    if (proportion == 0) {
        add_to_pool_by_proportion(
            deposit_amount=deposit_amount,
            pool_count=pool_count - 1,
            starter_index=starter_index + 1,
            prop_tracker=prop_tracker,
            remaining_amount=remaining_amount,
        );

        return ();
        // when loop comes to last pool we should stake all remaining balance to last pool
        // do it with prop tracker
    } else {
        let (staking_address) = staking_protocol_address_storage.read();
        // to avoid remainder issue
        let is_100 = prop_tracker + proportion;
        if (is_100 == 100) {
            // IStaking.stake(
            //     contract_address=staking_address, amount=remaining_amount, pair_id=available_pool_id
            // );
            return ();
        }

        let multiplied_amount = proportion * deposit_amount;
        let (deposit_stake, _) = unsigned_div_rem(multiplied_amount, 100);

        IStaking.stake(
            contract_address=staking_address, amount=deposit_stake, pair_id=available_pool_id
        );

        // deposit amount yerine remaining+amount koncak sonra  ilk loop icin
        // remaining amounta deposit amount denecek
        let remaining = deposit_amount - deposit_stake;

        add_to_pool_by_proportion(
            deposit_amount=deposit_amount,
            pool_count=pool_count - 1,
            starter_index=starter_index + 1,
            prop_tracker=prop_tracker + proportion,
            remaining_amount=remaining,
        );

        return ();
    }
}

@external
func transferOwnership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newOwner: felt
) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func pause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    Pausable._pause();
    return ();
}

@external
func unpause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    Pausable._unpause();
    return ();
}

//
// BRIDGE HANDLERS
//

// @l1_handler
// func distribute_with_random{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     from_address: felt, random_number: felt
// ) {
//     let l1_address = L1_vrf_bridge_address_storage.read();

// with_attr error_message("l1 address is not compatible") {
//         assert l1_address = from_address;
//     }

// let winner_address = distribute_reward(random_number=random_number);
//     return ();
// }
