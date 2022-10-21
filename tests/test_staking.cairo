%lang starknet
from starkware.cairo.common.uint256 import Uint256
from src.i_staking import IStaking
from starkware.starknet.common.syscalls import get_block_timestamp
from src.i_token import IToken

const OWNER1 = 10;
const ALICE = 1;
const BOB = 2;
const CAROL = 3;
const POW18 = 1000000000000000000;
const POW16 = 10000000000000000;

@external
func __setup__() {
    %{ context.staking_contract_address = deploy_contract("./src/staking.cairo").contract_address %}
    %{ context.staking_token_address = deploy_contract("./src/staking_token.cairo", [ids.OWNER1]).contract_address %}
    %{ context.reward_token_address = deploy_contract("./src/reward_token.cairo", [ids.OWNER1]).contract_address %}

    return ();
}

@external
func test_all_functions{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    tempvar staking_contract_address: felt;
    tempvar staking_token_address: felt;
    tempvar reward_token_address: felt;

    %{ ids.staking_contract_address = context.staking_contract_address %}
    %{ ids.staking_token_address = context.staking_token_address %}
    %{ ids.reward_token_address = context.reward_token_address %}

    assert 1000000000000000000 = POW18;
    // add token pair
    %{ stop_prank = start_prank(ids.OWNER1, ids.staking_contract_address) %}
    IStaking.add_token_pair(
        staking_contract_address, 111, staking_token_address, 222, reward_token_address
    );
    %{ stop_prank() %}

    let (pair_owner) = IStaking.get_pair_owner(staking_contract_address, 1);
    assert OWNER1 = pair_owner;
    let (id) = IStaking.get_last_pair_id(staking_contract_address);
    assert id = 1;

    // set rewards duration
    %{ stop_prank = start_prank(ids.OWNER1, ids.staking_contract_address) %}
    let six_hundred_18 = 600 * POW18;
    assert 600000000000000000000 = six_hundred_18;

    let six_hundred: Uint256 = Uint256(six_hundred_18, 0);
    IStaking.set_rewards_duration(staking_contract_address, 50, 1);

    %{ stop_prank_token = start_prank(ids.OWNER1, ids.reward_token_address) %}
    IToken.mint(reward_token_address, OWNER1, six_hundred);
    IToken.approve(reward_token_address, staking_contract_address, six_hundred);
    %{ stop_prank_token() %}

    let (owner1_balance) = IToken.balanceOf(reward_token_address, OWNER1);
    assert six_hundred = owner1_balance;
    // set reward amount, warp here because set rew am. assigns finish_at
    // finish_at -> 0 + 50 = 50
    %{ stop_warp = warp(0, ids.staking_contract_address) %}

    IStaking.set_reward_amount(staking_contract_address, six_hundred_18, 1);
    %{ stop_warp() %}
    let (staking_contract_reward_balance) = IToken.balanceOf(
        reward_token_address, staking_contract_address
    );
    assert six_hundred = staking_contract_reward_balance;

    let (on_contract_balance) = IStaking.get_reward_token_balance_of_this_contract(
        staking_contract_address, 1
    );
    let uint_on_contract_balance: Uint256 = Uint256(on_contract_balance, 0);
    assert staking_contract_reward_balance = uint_on_contract_balance;

    let (rate) = IStaking.get_reward_rate(staking_contract_address, 1);
    let twelve_18 = 12 * POW18;
    assert twelve_18 = rate;

    let (finish) = IStaking.get_finish_at(staking_contract_address, 1);
    assert 50 = finish;
    %{ stop_prank() %}

    // staking tokens tranfered to users
    %{ stop_prank_token = start_prank(ids.OWNER1, ids.staking_token_address) %}
    let two_hundred_18 = 200 * POW18;
    let two_hundred: Uint256 = Uint256(two_hundred_18, 0);
    IToken.mint(staking_token_address, OWNER1, six_hundred);
    IToken.transfer(staking_token_address, ALICE, two_hundred);
    IToken.transfer(staking_token_address, BOB, two_hundred);
    IToken.transfer(staking_token_address, CAROL, two_hundred);
    %{ stop_prank_token() %}

    // users approve staking contract
    %{ stop_prank = start_prank(ids.ALICE, ids.staking_token_address) %}
    IToken.approve(staking_token_address, staking_contract_address, two_hundred);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.BOB, ids.staking_token_address) %}
    IToken.approve(staking_token_address, staking_contract_address, two_hundred);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.CAROL, ids.staking_token_address) %}
    IToken.approve(staking_token_address, staking_contract_address, two_hundred);
    %{ stop_prank() %}

    let one_hundred_18 = 100 * POW18;
    let one_hundred: Uint256 = Uint256(one_hundred_18, 0);
    // at time 3, ALICE stakes 100 token
    %{ stop_warp = warp(3, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.ALICE, ids.staking_contract_address) %}
    IStaking.stake(staking_contract_address, one_hundred_18, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}
    // tests for writes
    let (alice_balance) = IToken.balanceOf(staking_token_address, ALICE);
    assert one_hundred = alice_balance;

    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert one_hundred = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    assert 0 = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 3 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, ALICE);
    assert 0 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, ALICE);
    assert 0 = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, ALICE);
    assert one_hundred_18 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert one_hundred_18 = total;

    // at time 5, BOB stakes 200 token
    %{ stop_warp = warp(5, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.BOB, ids.staking_contract_address) %}
    IStaking.stake(staking_contract_address, two_hundred_18, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let zero: Uint256 = Uint256(0, 0);
    let (bob_balance) = IToken.balanceOf(staking_token_address, BOB);
    assert zero = bob_balance;
    let three_hundred_18 = 300 * POW18;
    let three_hundred: Uint256 = Uint256(three_hundred_18, 0);
    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert three_hundred = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    let king_kong = 24 * POW16;
    assert king_kong = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 5 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, BOB);
    assert 0 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, BOB);
    assert king_kong = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, BOB);
    assert two_hundred_18 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert three_hundred_18 = total;

    // at time 6, CAROL stakes 100 token
    %{ stop_warp = warp(6, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.CAROL, ids.staking_contract_address) %}
    IStaking.stake(staking_contract_address, one_hundred_18, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (carol_balance) = IToken.balanceOf(staking_token_address, CAROL);
    assert one_hundred = carol_balance;
    let four_hundred_18 = 400 * POW18;
    let four_hundred: Uint256 = Uint256(four_hundred_18, 0);
    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert four_hundred = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    let king_kong = 28 * POW16;
    assert king_kong = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 6 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, CAROL);
    assert 0 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, CAROL);
    assert king_kong = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, CAROL);
    assert one_hundred_18 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert four_hundred_18 = total;

    // at time 9, ALICE withdraws 100 token
    %{ stop_warp = warp(9, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.ALICE, ids.staking_contract_address) %}
    IStaking.withdraw(staking_contract_address, one_hundred_18, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (alice_balance) = IToken.balanceOf(staking_token_address, ALICE);
    assert two_hundred = alice_balance;

    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert three_hundred = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    let king_kong = 37 * POW16;
    assert king_kong = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 9 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, ALICE);
    let thirty_seven_18 = 37 * POW18;
    assert thirty_seven_18 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, ALICE);
    assert king_kong = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, ALICE);
    assert 0 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert three_hundred_18 = total;

    // at time 10 CAROL stakes another 100 and alice claims reward
    %{ stop_warp = warp(10, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.CAROL, ids.staking_contract_address) %}
    IStaking.stake(staking_contract_address, one_hundred_18, 1);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.ALICE, ids.staking_contract_address) %}
    IStaking.get_reward(staking_contract_address, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (carol_balance) = IToken.balanceOf(staking_token_address, CAROL);
    assert zero = carol_balance;

    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert four_hundred = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    let king_kong = 41 * POW16;  // tekrar hesap
    assert king_kong = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 10 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, CAROL);
    let thirteen_18 = 13 * POW18;
    assert thirteen_18 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, CAROL);
    assert king_kong = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, CAROL);
    assert two_hundred_18 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert four_hundred_18 = total;

    let (reward_token_balance_ALICE) = IToken.balanceOf(reward_token_address, ALICE);
    let thirty_seven: Uint256 = Uint256(thirty_seven_18, 0);
    assert thirty_seven = reward_token_balance_ALICE;

    // at time 11, BOB withdraws 200 token
    %{ stop_warp = warp(11, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.BOB, ids.staking_contract_address) %}
    IStaking.withdraw(staking_contract_address, two_hundred_18, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (bob_balance) = IToken.balanceOf(staking_token_address, BOB);
    assert two_hundred = bob_balance;

    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert two_hundred = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    let king_kong = 44 * POW16;
    assert king_kong = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 11 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, BOB);
    let fourty_18 = 40 * POW18;
    assert fourty_18 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, BOB);
    assert king_kong = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, BOB);
    assert 0 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert two_hundred_18 = total;

    // at time 13, CAROL withdraws 200 token and claims reward
    // BOB claims reward
    %{ stop_warp = warp(13, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.CAROL, ids.staking_contract_address) %}
    IStaking.withdraw(staking_contract_address, two_hundred_18, 1);
    IStaking.get_reward(staking_contract_address, 1);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.BOB, ids.staking_contract_address) %}
    IStaking.get_reward(staking_contract_address, 1);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (carol_balance) = IToken.balanceOf(staking_token_address, CAROL);
    assert two_hundred = carol_balance;

    let (contract_balance) = IToken.balanceOf(staking_token_address, staking_contract_address);
    assert zero = contract_balance;

    let (reward_per_token_stored) = IStaking.get_reward_per_token(staking_contract_address, 1);
    let king_kong = 56 * POW16;
    assert king_kong = reward_per_token_stored;

    let (updated_at) = IStaking.get_updated_at(staking_contract_address, 1);
    assert 13 = updated_at;

    let (reward) = IStaking.get_rewards(staking_contract_address, 1, CAROL);
    let thirty_18 = 30 * POW18;
    assert 0 = reward;

    let (usrpt) = IStaking.get_user_reward_per_token_paid(staking_contract_address, 1, CAROL);
    assert king_kong = usrpt;

    let (staked) = IStaking.get_balance_of_staked_token(staking_contract_address, 1, CAROL);
    assert 0 = staked;

    let (total) = IStaking.get_total_staked(staking_contract_address, 1);
    assert 0 = total;

    let (reward_token_balance_BOB) = IToken.balanceOf(reward_token_address, BOB);
    let fourty: Uint256 = Uint256(fourty_18, 0);
    assert fourty = reward_token_balance_BOB;

    let (reward_token_balance_CAROL) = IToken.balanceOf(reward_token_address, CAROL);
    let fourty_three_18 = 43 * POW18;
    let fourty_three: Uint256 = Uint256(fourty_three_18, 0);
    assert fourty_three = reward_token_balance_CAROL;

    return ();

    // an address calls other than owner set rewards duration
}

// @external
// func test_example{syscall_ptr: felt*, range_check_ptr}() {
//     alloc_locals;

// tempvar staking_contract_address: felt;
//     tempvar staking_token_address: felt;
//     tempvar reward_token_address: felt;

// %{ ids.staking_contract_address = context.staking_contract_address %}
//     %{ ids.staking_token_address = context.staking_token_address %}
//     %{ ids.reward_token_address = context.reward_token_address %}

// IStaking.add_token_pair(
//         staking_contract_address, 15, staking_token_address, 30, reward_token_address
//     );

// let (id) = IStaking.get_last_pair_id(staking_contract_address);
//     assert id = 1;

// %{ stop_warp = warp(10) %}

// let (bt) = get_block_timestamp();
//     assert bt = 10;
//     let (finish) = IStaking.get_finish_at(staking_contract_address, 1);
//     assert finish = 0;
//     IStaking.set_rewards_duration(staking_contract_address, 1515, 1);
//     %{ stop_warp() %}

// return ();
// }
