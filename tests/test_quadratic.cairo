%lang starknet

from src.interfaces.i_token import IToken
from src.interfaces.i_staking import IStaking
from src.interfaces.i_quadratic import IQuadratic
from starkware.cairo.common.uint256 import Uint256

const OWNER1 = 10;
const user1 = 20;
const user2 = 21;
const user3 = 22;

const POW18 = 1000000000000000000;

// VRF bridge adresini degistir setuptan yapinca1
// @external
// func __setup__() {
//     %{ context.staking_contract_address = deploy_contract("./src/staking.cairo").contract_address %}
//     %{ context.stable_token_address = deploy_contract("./src/stable_token.cairo", [ids.OWNER1]).contract_address %}
//     %{ context.reward_token_address = deploy_contract("./src/reward_token.cairo", [ids.OWNER1]).contract_address %}
//     %{ context.quadratic_address = deploy_contract("./src/quadratic_ref_lottery_V1.cairo", [ids.OWNER1, context.staking_contract_address, context.stable_token_address, 0]).contract_address %}
//     return ();  // { "initial_balance": 42, "contract_id": 123 })
// }

@external
func test_all_functions{syscall_ptr: felt*, range_check_ptr}() {
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

    let number_301 = 301 * POW18;
    let n_301: Uint256 = Uint256(number_301, 0);

    let number_101 = 101 * POW18;
    let n_101: Uint256 = Uint256(number_101, 0);

    let number_100 = 100 * POW18;
    let n_100: Uint256 = Uint256(number_100, 0);
    // first batch of users for criticial tests
    %{ stop_prank_token = start_prank(ids.OWNER1, ids.stable_token_address) %}

    IToken.mint(stable_token_address, OWNER1, n_301);
    IToken.transfer(stable_token_address, user1, n_101);
    IToken.transfer(stable_token_address, user2, n_100);
    IToken.transfer(stable_token_address, user3, n_100);
    %{ stop_prank_token() %}

    %{ stop_prank = start_prank(ids.user1, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, n_101);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user2, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, n_100);
    %{ stop_prank() %}
    %{ stop_prank = start_prank(ids.user3, ids.stable_token_address) %}
    IToken.approve(stable_token_address, quadratic_address, n_100);
    %{ stop_prank() %}

    // 3,2,1 dene
    %{ stop_prank = start_prank(ids.OWNER1, ids.quadratic_address) %}
    IQuadratic.add_new_pool(quadratic_address, 1, 30);
    IQuadratic.add_new_pool(quadratic_address, 2, 30);
    IQuadratic.add_new_pool(quadratic_address, 3, 40);
    %{ stop_prank() %}

    let (balance) = IToken.balanceOf(stable_token_address, user1);
    assert n_101 = balance;

    %{ stop_warp = warp(1, ids.staking_contract_address) %}
    %{ stop_prank = start_prank(ids.user1, ids.quadratic_address) %}
    IQuadratic.buy_slot(quadratic_address, number_101);
    %{ stop_prank() %}
    %{ stop_warp() %}

    // let (balance) = IToken.balanceOf(stable_token_address, quadratic_address);
    // assert n_101 = balance;

    // let (allowance) = IToken.allowance(
    //     contract_address=stable_token_address,
    //     owner=quadratic_address,
    //     spender=staking_contract_address,
    // );
    // assert n_101 = allowance;

    // let (balance1) = IStaking.get_balance_of_staked_token(staking_contract_address, user1, 1);
    // assert 30 * POW18 = balance1;

    // let (balance2) = IStaking.get_balance_of_staked_token(staking_contract_address, user1, 2);
    // assert 30 * POW18 = balance2;

    // let (balance3) = IStaking.get_balance_of_staked_token(staking_contract_address, user1, 3);
    // assert 41 * POW18 = balance3;

    return ();
}
