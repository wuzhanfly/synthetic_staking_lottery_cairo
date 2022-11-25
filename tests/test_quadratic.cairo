%lang starknet

from src.interfaces.i_token import IToken
from src.interfaces.i_staking import IStaking
from src.interfaces.i_quadratic import IQuadratic
from starkware.cairo.common.uint256 import Uint256

const OWNER1 = 10;
const user1 = 20;
const user2 = 21;
const user3 = 22;
const user4 = 23;

const POW18 = 1000000000000000000;

// VRF bridge adresini degistir setuptan yapinca1

@external
func test_for_four{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    local staking_contract_address: felt;
    local stable_token_address: felt;
    local reward_token_address: felt;
    local quadratic_address: felt;

    %{ ids.staking_contract_address = deploy_contract("./src/staking.cairo").contract_address %}
    %{ ids.stable_token_address = deploy_contract("./src/stable_token.cairo", [ids.OWNER1]).contract_address %}
    %{ ids.reward_token_address = deploy_contract("./src/reward_token.cairo", [ids.OWNER1]).contract_address %}
    %{ ids.quadratic_address = deploy_contract("./src/quadratic_ref_lottery_V1.cairo", [ids.OWNER1, ids.staking_contract_address, ids.stable_token_address, 0]).contract_address %}
    // %{ ids.staking_contract_address = context.staking_contract_address %}
    // %{ ids.stable_token_address = context.stable_token_address %}
    // %{ ids.reward_token_address = context.reward_token_address %}
    // %{ ids.quadratic_address = context.quadratic_address %}

    %{ stop_prank = start_prank(ids.OWNER1, ids.staking_contract_address) %}

    IStaking.add_token_pair(
        staking_contract_address, 1, stable_token_address, 2, reward_token_address
    );

    IStaking.set_rewards_duration(staking_contract_address, 15780000, 1);

    IStaking.add_token_pair(
        staking_contract_address, 11, stable_token_address, 22, reward_token_address
    );

    IStaking.set_rewards_duration(staking_contract_address, 15780000, 2);

    IStaking.add_token_pair(
        staking_contract_address, 111, stable_token_address, 222, reward_token_address
    );

    IStaking.set_rewards_duration(staking_contract_address, 15780000, 3);

    let sixty_million_18 = 60000000 * POW18;
    let sixty_million: Uint256 = Uint256(sixty_million_18, 0);

    %{ stop_prank_token = start_prank(ids.OWNER1, ids.reward_token_address) %}
    IToken.mint(reward_token_address, OWNER1, sixty_million);
    IToken.approve(reward_token_address, staking_contract_address, sixty_million);
    %{ stop_prank_token() %}

    let twenty_million_18 = 20000000 * POW18;

    %{ stop_warp = warp(0, ids.staking_contract_address) %}
    IStaking.set_reward_amount(staking_contract_address, twenty_million_18, 1);
    IStaking.set_reward_amount(staking_contract_address, twenty_million_18, 2);
    IStaking.set_reward_amount(staking_contract_address, twenty_million_18, 3);
    %{ stop_warp() %}

    %{ stop_prank() %}

    let number_literal = 300 * POW18 + 101;
    let n_literal: Uint256 = Uint256(number_literal, 0);

    let number_100 = 100 * POW18;
    let n_100: Uint256 = Uint256(number_100, 0);

    let not18_101 = Uint256(101, 0);
    // first batch of users for criticial tests
    %{ stop_prank_token = start_prank(ids.OWNER1, ids.stable_token_address) %}

    IToken.mint(stable_token_address, OWNER1, n_literal);
    IToken.transfer(stable_token_address, user1, not18_101);
    IToken.transfer(stable_token_address, user2, n_100);
    IToken.transfer(stable_token_address, user3, n_100);
    IToken.transfer(stable_token_address, user4, n_100);
    %{ stop_prank_token() %}

    %{ stop_prank = start_prank(ids.user1, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, not18_101);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user2, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, n_literal);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user3, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, n_100);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user4, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, n_100);
    %{ stop_prank() %}

    // 3,2,1 dene
    %{ stop_prank = start_prank(ids.OWNER1, ids.quadratic_address) %}
    IQuadratic.add_new_pool(quadratic_address, 1, 30);
    IQuadratic.add_new_pool(quadratic_address, 2, 30);
    IQuadratic.add_new_pool(quadratic_address, 3, 40);
    %{ stop_prank() %}

    let (pool_count) = IQuadratic.get_pool_count(quadratic_address);
    assert 3 = pool_count;

    let (balance) = IToken.balanceOf(stable_token_address, user1);
    assert not18_101 = balance;

    %{ stop_warp = warp(1, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user1, ids.quadratic_address) %}
    IQuadratic.buy_slot(quadratic_address, 101);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (balance) = IToken.balanceOf(stable_token_address, staking_contract_address);
    assert not18_101 = balance;

    let (balance1) = IStaking.get_balance_of_staked_token(
        staking_contract_address, 1, quadratic_address
    );

    assert 30 = balance1;

    // pool count arttir

    let (balance2) = IStaking.get_balance_of_staked_token(
        staking_contract_address, 2, quadratic_address
    );
    assert 30 = balance2;

    let (balance3) = IStaking.get_balance_of_staked_token(
        staking_contract_address, 3, quadratic_address
    );
    assert 41 = balance3;

    let (user1_balance) = IQuadratic.get_user_balance(quadratic_address, user1);
    assert 101 = user1_balance;

    let (user1_squared_balance) = IQuadratic.get_user_squared_balance(quadratic_address, user1);
    assert 10 = user1_squared_balance;

    let (user1id) = IQuadratic.learn_user_id(quadratic_address, user1);
    assert 1 = user1id;

    %{ stop_warp = warp(5, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user2, ids.quadratic_address) %}
    IQuadratic.buy_slot(quadratic_address, number_100);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (user2id) = IQuadratic.learn_user_id(quadratic_address, user2);
    assert 2 = user2id;

    %{ stop_warp = warp(6, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user3, ids.quadratic_address) %}
    IQuadratic.buy_slot(quadratic_address, number_100);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (user3id) = IQuadratic.learn_user_id(quadratic_address, user3);
    assert 3 = user3id;

    let (idle_id) = IQuadratic.get_idle_id(quadratic_address, 2);
    assert 0 = idle_id;

    %{ stop_warp = warp(10, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user2, ids.quadratic_address) %}
    IQuadratic.sell_slot(quadratic_address, number_100);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (idle_id) = IQuadratic.get_idle_id(quadratic_address, 2);
    assert 2 = idle_id;

    %{ stop_warp = warp(12, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user4, ids.quadratic_address) %}
    IQuadratic.buy_slot(quadratic_address, number_100);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (id) = IQuadratic.learn_user_id(quadratic_address, user4);
    assert 2 = id;

    %{ stop_warp = warp(13, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user2, ids.quadratic_address) %}
    IQuadratic.buy_slot(quadratic_address, number_100);
    %{ stop_prank() %}
    %{ stop_warp() %}

    let (id) = IQuadratic.learn_user_id(quadratic_address, user2);
    assert 4 = id;
    return ();
}
