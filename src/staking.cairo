%lang starknet

from src.interfaces.i_token import IToken
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
)
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.pow import pow

struct Pair {
    pair_owner_address: felt,
    for_stake_address: felt,
    for_stake_name: felt,
    for_reward_address: felt,
    for_reward_name: felt,
}

//
//   EVENTS
//

@event
func add_token_pair_called(added_pair_info: Pair, added_pair_id: felt) {
}

@event
func set_rewards_duration_called(duration: felt, pair_id: felt) {
}

@event
func set_reward_amount_called(amount: felt, pair_id: felt, updated_at: felt, finish_at: felt) {
}

@event
func stake_called(amount: felt, user_address: felt, pair_id: felt) {
}

@event
func withdraw_called(amount: felt, user_address: felt, pair_id: felt) {
}

@event
func get_reward_called(reward: felt, user_address: felt, pair_id: felt) {
}

//
//   STORAGE
//

@storage_var
func last_pair_id_storage() -> (last_pair_id: felt) {
}

// PAIR INFO

@storage_var
func pair_info_storage(pair_id: felt) -> (pair_info: Pair) {
}

@storage_var
func reward_duration_storage(pair_id: felt) -> (reward_duration: felt) {
}

@storage_var
func finish_at_storage(pair_id: felt) -> (finish_at: felt) {
}

@storage_var
func reward_rate_storage(pair_id: felt) -> (reward_rate: felt) {
}

@storage_var
func updated_at_storage(pair_id: felt) -> (updated_at: felt) {
}

@storage_var
func total_staked_storage(pair_id: felt) -> (total_staked: felt) {
}

@storage_var
func reward_per_token_storage(pair_id: felt) -> (reward_per_token_stored: felt) {
}

@storage_var
func reward_token_balance_in_this_contract_storage(pair_id: felt) -> (reward_balance: felt) {
}

// USER INFO

@storage_var
func balance_of_staked_token(user_address: felt, pair_id: felt) -> (staked_balance: felt) {
}

@storage_var
func user_reward_per_token_paid(user_address: felt, pair_id: felt) -> (res: felt) {
}

@storage_var
func rewards(user_address: felt, pair_id: felt) -> (reward: felt) {
}

//
//   FUNCS
//

func min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(a: felt, b: felt) -> (
    min: felt
) {
    let bool = is_le(a, b);

    if (bool == TRUE) {
        return (a,);
    } else {
        return (b,);
    }
}

func get_last_time_reward_applicable{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(pair_id: felt, finish_at: felt) -> (finish_or_not: felt) {
    let (block_timestamp) = get_block_timestamp();

    let (finished_or_not) = min(block_timestamp, finish_at);

    return (finished_or_not,);
}

// if total amount of staked token is zero formula doesent work
// you cant divide by 0, so there is a if statement for first stake
func reward_per_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (reward_per_t: felt) {
    alloc_locals;

    let (total_staked) = total_staked_storage.read(pair_id);
    if (total_staked == 0) {
        let (reward_per_t) = reward_per_token_storage.read(pair_id);
        return (reward_per_t=reward_per_t);
    } else {
        let (block_timestamp) = get_block_timestamp();
        let (finish_at) = finish_at_storage.read(pair_id);

        let (last_time_reward_applicable) = min(block_timestamp, finish_at);
        let (pow18) = pow(10, 18);

        let (rpts) = reward_per_token_storage.read(pair_id);

        let (reward_rate) = reward_rate_storage.read(pair_id);

        let (updated_at) = updated_at_storage.read(pair_id);

        let divide_it_to_staked = (reward_rate * (last_time_reward_applicable - updated_at) * pow18);

        let (reward_per_t, _) = unsigned_div_rem(divide_it_to_staked, total_staked);
        // duration since last updated time

        return (reward_per_t=reward_per_t + rpts);
    }
}

// if reward is still ongoing this func will return current timestamp
// if reward duration has expired this func will return the time
// when the reward has expired

func update_reward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address: felt, pair_id: felt
) {
    alloc_locals;
    local r_p_t: felt;

    let (cairo_is_boring) = reward_per_token(pair_id=pair_id);
    assert r_p_t = cairo_is_boring;
    // add test case
    reward_per_token_storage.write(pair_id=pair_id, value=r_p_t);

    let (block_timestamp) = get_block_timestamp();
    let (finish_at) = finish_at_storage.read(pair_id);
    let (last_time_reward_applicable) = min(block_timestamp, finish_at);

    // add test case for this write
    updated_at_storage.write(pair_id=pair_id, value=last_time_reward_applicable);

    let bool = is_not_zero(user_address);
    if (bool == TRUE) {
        let (earned_) = earned(user_address=user_address, pair_id=pair_id);
        // add test case for this write
        rewards.write(user_address=user_address, pair_id=pair_id, value=earned_);

        let (reward_per_token_stored) = reward_per_token_storage.read(pair_id);
        // add test case for this
        user_reward_per_token_paid.write(
            user_address=user_address, pair_id=pair_id, value=reward_per_token_stored
        );
        return ();
    }
    return ();
}

//
//   VIEW
//
@view
func get_reward_per_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (reward_per_token_stored: felt) {
    let (reward_per_token_stored) = reward_per_token_storage.read(pair_id=pair_id);
    return (reward_per_token_stored=reward_per_token_stored);
}

@view
func get_updated_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (updated_at: felt) {
    let (updated_at) = updated_at_storage.read(pair_id=pair_id);
    return (updated_at=updated_at);
}

@view
func get_rewards{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt, user_address: felt
) -> (rewards: felt) {
    let (reward) = rewards.read(user_address=user_address, pair_id=pair_id);
    return (rewards=reward);
}

@view
func get_user_reward_per_token_paid{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(pair_id: felt, user_address: felt) -> (usrpt: felt) {
    let (usrpt) = user_reward_per_token_paid.read(user_address=user_address, pair_id=pair_id);
    return (usrpt=usrpt);
}
@view
func get_balance_of_staked_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt, user_address: felt
) -> (staked: felt) {
    let (staked) = balance_of_staked_token.read(user_address=user_address, pair_id=pair_id);
    return (staked=staked);
}

@view
func get_total_staked{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (total: felt) {
    let (total) = total_staked_storage.read(pair_id=pair_id);
    return (total=total);
}

@view
func get_pair_information{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (
    pair_info: Pair,
    reward_duration: felt,
    finish_at: felt,
    reward_rate: felt,
    updated_at: felt,
    total_staked: felt,
    reward_per_token_stored: felt,
    reward_token_balance_in_this_contract: felt,
) {
    let (pair_info: Pair) = pair_info_storage.read(pair_id);
    let (reward_duration) = reward_duration_storage.read(pair_id);
    let (finish_at) = finish_at_storage.read(pair_id);
    let (reward_rate) = reward_rate_storage.read(pair_id);
    let (updated_at) = updated_at_storage.read(pair_id);
    let (total_staked) = total_staked_storage.read(pair_id);
    let (reward_per_token_stored) = reward_per_token_storage.read(pair_id);
    let (
        reward_token_balance_in_this_contract
    ) = reward_token_balance_in_this_contract_storage.read(pair_id);

    return (
        pair_info,
        reward_duration,
        finish_at,
        reward_rate,
        updated_at,
        total_staked,
        reward_per_token_stored,
        reward_token_balance_in_this_contract,
    );
}

@view
func get_finish_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (finish_at: felt) {
    let (finish) = finish_at_storage.read(pair_id=pair_id);
    return (finish_at=finish);
}

@view
func get_last_pair_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    last_pair_id: felt
) {
    let (last_pair_id) = last_pair_id_storage.read();
    return (last_pair_id=last_pair_id);
}

@view
func get_pair_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (pair_owner: felt) {
    let (pair_info: Pair) = pair_info_storage.read(pair_id=pair_id);
    let owner = pair_info.pair_owner_address;
    return (pair_owner=owner);
}

@view
func get_reward_token_balance_of_this_contract{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(pair_id: felt) -> (balance: felt) {
    let (token_balance) = reward_token_balance_in_this_contract_storage.read(pair_id);
    return (balance=token_balance);
}

@view
func get_reward_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (rate: felt) {
    let (reward_rate) = reward_rate_storage.read(pair_id);
    return (rate=reward_rate);
}
@view
func get_user_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    pair_id: felt
) -> (balance_of_staked_token: felt, user_reward_per_token_paid: felt, rewards: felt) {
    let (caller_address) = get_caller_address();
    let (_balance_of_staked_token) = balance_of_staked_token.read(caller_address, pair_id);
    let (_user_reward_per_token_paid) = user_reward_per_token_paid.read(caller_address, pair_id);
    let (_rewards) = rewards.read(caller_address, pair_id);

    return (_balance_of_staked_token, _user_reward_per_token_paid, _rewards);
}

// amount of rewards earned by a user can be computed by
// the amount of token staked * ( reward_per_token - user_reward_per_token_paid )
@view
func earned{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user_address: felt, pair_id: felt
) -> (earned: felt) {
    alloc_locals;
    let (staked_balance) = balance_of_staked_token.read(user_address=user_address, pair_id=pair_id);
    let (reward_per_token_) = reward_per_token(pair_id);
    let (urpp) = user_reward_per_token_paid.read(user_address=user_address, pair_id=pair_id);
    let (prev_reward) = rewards.read(user_address=user_address, pair_id=pair_id);
    let (pow18) = pow(10, 18);
    // this number is scaled up by 10 ** 18 so i divide it
    let rewards_earned = staked_balance * (reward_per_token_ - urpp);

    let (_rewards_earned_, _) = unsigned_div_rem(rewards_earned, pow18);

    return (_rewards_earned_ + prev_reward,);
}

//
//   EXTERNAL
//

@external
func add_token_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    for_stake_token_name: felt,
    for_stake_token_address: felt,
    for_reward_token_name: felt,
    for_reward_token_address: felt,
) {
    let (caller_address) = get_caller_address();
    let (last_pid) = last_pair_id_storage.read();
    let new_pid = last_pid + 1;
    last_pair_id_storage.write(new_pid);

    let pair_instance = Pair(
        pair_owner_address=caller_address,
        for_stake_address=for_stake_token_address,
        for_stake_name=for_stake_token_name,
        for_reward_address=for_reward_token_address,
        for_reward_name=for_reward_token_name,
    );

    pair_info_storage.write(pair_id=new_pid, value=pair_instance);

    add_token_pair_called.emit(added_pair_info=pair_instance, added_pair_id=new_pid);
    return ();
}

// owner of the pair should set a duration
// previous reward should be ended (?)
@external
func set_rewards_duration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    duration: felt, pair_id: felt
) {
    alloc_locals;

    with_attr error_message("Duration is 0 or negative") {
        assert_nn(duration - 1);
    }

    let (caller_address) = get_caller_address();
    let (pair_info: Pair) = pair_info_storage.read(pair_id=pair_id);
    let pair_owner = pair_info.pair_owner_address;

    with_attr error_message("Caller is not pair owner or non-existent pair") {
        assert caller_address = pair_owner;
    }

    let (finish_at) = finish_at_storage.read(pair_id);
    let (block_timestamp) = get_block_timestamp();

    // assert_lt doesnt work on protostar test, gives error_message
    with_attr error_message("Reward duration not finished") {
        assert_le(finish_at, block_timestamp);
    }

    reward_duration_storage.write(pair_id=pair_id, value=duration);
    set_rewards_duration_called.emit(duration=duration, pair_id=pair_id);
    return ();
}

// owner of the pair sets reward rate, amount of the rewards to be paid for the duration
// there are two cases to set the reward rate, calculation
// depends on whether current reward duration expired or not

// this func can be updated to two options for reward provider
// 1 (this func only involve this case): adding amount to existing finish_at
// and extend finish_at by duration
// 2 : adding amount to existing finish_at and not changing instance
// reward duration by duration

// instead of adding duration again, finish at could be constant
// and can be determined when reward added first time based on duration
// so that user can add new rewards for remaining duration
// in that case i shouldnt update finish_at and should update
// new_reward_rate with finish_at - block.timestamp instead of pair_duration

// if a person doesnt want their some token is locked in this contract
// and doesnt contribute to reward_rate they should provide a amount and duration
// that have a remainder that is 0, i can create an assert statement to ensure that
@external
func set_reward_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, pair_id: felt
) {
    alloc_locals;

    with_attr error_message("Amount is 0 or negative") {
        assert_nn(amount - 1);
    }

    let (caller_address) = get_caller_address();
    let pair_info: Pair = pair_info_storage.read(pair_id=pair_id);

    with_attr error_message("Caller is not pair owner.") {
        assert caller_address = pair_info.pair_owner_address;
    }

    let for_reward_token_address = pair_info.for_reward_address;
    let (address_this) = get_contract_address();

    let uint256_amount: Uint256 = Uint256(amount, 0);

    let (success) = IToken.transferFrom(
        contract_address=for_reward_token_address,
        sender=caller_address,
        recipient=address_this,
        amount=uint256_amount,
    );

    with_attr error_message("Transfer has failed") {
        assert success = TRUE;
    }

    reward_token_balance_in_this_contract_storage.write(pair_id=pair_id, value=amount);

    let (pair_duration) = reward_duration_storage.read(pair_id=pair_id);

    // It should be 0 if first time. Should initilaize at add pair?
    let (finish_at) = finish_at_storage.read(pair_id);
    let (block_timestamp) = get_block_timestamp();
    let comparison_bool = is_le(finish_at, block_timestamp - 1);
    // reward duration expired or not started

    if (comparison_bool == 1) {
        // remaining amount shouldnt be received to contract i guess
        let (reward_rate, _) = unsigned_div_rem(amount, pair_duration);
        reward_rate_storage.write(pair_id=pair_id, value=reward_rate);
        // there is some ongoing rewards and stakers earning the rewards
    } else {
        // first compute amount of rewards remaining and add amount input
        let (reward_rate) = reward_rate_storage.read(pair_id);
        let remaining_rewards = reward_rate * (finish_at - block_timestamp);
        let (new_reward_rate, _) = unsigned_div_rem(remaining_rewards + amount, pair_duration);
        reward_rate_storage.write(pair_id=pair_id, value=new_reward_rate);
    }

    let (reward_rate) = reward_rate_storage.read(pair_id=pair_id);

    let (reward_balance) = reward_token_balance_in_this_contract_storage.read(pair_id=pair_id);
    let reward = reward_rate * pair_duration;

    with_attr error_message("Reward amount > balance") {
        assert_le(reward, reward_balance);
    }

    with_attr error_message("Reward rate == 0") {
        assert_nn(reward_rate - 1);
    }

    finish_at_storage.write(pair_id=pair_id, value=block_timestamp + pair_duration);
    updated_at_storage.write(pair_id=pair_id, value=block_timestamp);

    set_reward_amount_called.emit(
        amount=amount,
        pair_id=pair_id,
        updated_at=block_timestamp,
        finish_at=block_timestamp + pair_duration,
    );
    return ();
}

// user can stake relevant token
@external
func stake{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, pair_id: felt
) {
    alloc_locals;
    with_attr error_message("Amount is 0 or negative") {
        assert_nn(amount - 1);
    }

    let (caller_address) = get_caller_address();
    let (address_this) = get_contract_address();

    let (pair_info: Pair) = pair_info_storage.read(pair_id=pair_id);

    let uint256_amount: Uint256 = Uint256(amount, 0);
    let for_stake_token_address = pair_info.for_stake_address;

    let (success) = IToken.transferFrom(
        for_stake_token_address, caller_address, address_this, uint256_amount
    );

    with_attr error_message("Transfer has failed") {
        assert success = TRUE;
    }

    update_reward(user_address=caller_address, pair_id=pair_id);

    let (prev_balance) = balance_of_staked_token.read(user_address=caller_address, pair_id=pair_id);
    balance_of_staked_token.write(
        user_address=caller_address, pair_id=pair_id, value=prev_balance + amount
    );

    let (prev_staked) = total_staked_storage.read(pair_id=pair_id);
    total_staked_storage.write(pair_id=pair_id, value=prev_staked + amount);

    stake_called.emit(amount=amount, user_address=caller_address, pair_id=pair_id);
    return ();
}
// user can ` staked token
@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, pair_id: felt
) {
    alloc_locals;
    with_attr error_message("Amount == 0") {
        assert_nn(amount - 1);
    }

    let (caller_address) = get_caller_address();

    let (staked_balance) = balance_of_staked_token.read(
        user_address=caller_address, pair_id=pair_id
    );

    with_attr error_message("Cannot withdraw more than staked amount") {
        assert_le(amount, staked_balance);
    }

    let (pair_info: Pair) = pair_info_storage.read(pair_id=pair_id);
    let uint256_amount: Uint256 = Uint256(amount, 0);
    let for_stake_token_address = pair_info.for_stake_address;

    let (success) = IToken.transfer(for_stake_token_address, caller_address, uint256_amount);

    with_attr error_message("Transfer has failed") {
        assert success = TRUE;
    }

    update_reward(user_address=caller_address, pair_id=pair_id);

    let (prev_balance) = balance_of_staked_token.read(user_address=caller_address, pair_id=pair_id);
    balance_of_staked_token.write(
        user_address=caller_address, pair_id=pair_id, value=prev_balance - amount
    );

    let (prev_staked) = total_staked_storage.read(pair_id=pair_id);
    total_staked_storage.write(pair_id=pair_id, value=prev_staked - amount);

    withdraw_called.emit(amount=amount, user_address=caller_address, pair_id=pair_id);
    return ();
}
// user can claim their reward
@external
func get_reward{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(pair_id: felt) {
    alloc_locals;
    let (caller_address) = get_caller_address();
    update_reward(user_address=caller_address, pair_id=pair_id);
    let (pair_info: Pair) = pair_info_storage.read(pair_id);
    let (reward) = rewards.read(user_address=caller_address, pair_id=pair_id);

    let bool = is_nn(reward - 1);

    if (bool == TRUE) {
        rewards.write(user_address=caller_address, pair_id=pair_id, value=0);
        let for_reward_token_address = pair_info.for_reward_address;

        let uint256_reward: Uint256 = Uint256(reward, 0);
        let (success) = IToken.transfer(for_reward_token_address, caller_address, uint256_reward);

        with_attr error_message("Transfer has failed") {
            assert success = TRUE;
        }
        let (reward_locked) = reward_token_balance_in_this_contract_storage.read(pair_id=pair_id);
        reward_token_balance_in_this_contract_storage.write(
            pair_id=pair_id, value=reward_locked - reward
        );
        get_reward_called.emit(reward=reward, user_address=caller_address, pair_id=pair_id);
        return ();
    }
    return ();
}
