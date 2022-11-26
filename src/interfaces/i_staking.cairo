%lang starknet

from src.staking import Pair

@contract_interface
namespace IStaking {
    func get_reward_per_token(pair_id: felt) -> (reward_per_token_stored: felt) {
    }

    func get_updated_at(pair_id: felt) -> (updated_at: felt) {
    }

    func get_rewards(pair_id: felt, user_address: felt) -> (rewards: felt) {
    }

    func get_user_reward_per_token_paid(pair_id: felt, user_address: felt) -> (usrpt: felt) {
    }

    func get_balance_of_staked_token(pair_id: felt, user_address: felt) -> (staked: felt) {
    }

    func get_total_staked(pair_id: felt) -> (total: felt) {
    }

    func get_pair_information(pair_id: felt) -> (
        pair_info: Pair,
        reward_duration: felt,
        finish_at: felt,
        reward_rate: felt,
        updated_at: felt,
        total_staked: felt,
        reward_per_token_stored: felt,
        reward_token_balance_in_this_contract: felt,
    ) {
    }

    func get_finish_at(pair_id: felt) -> (finish_at: felt) {
    }

    func get_last_pair_id() -> (last_pair_id: felt) {
    }

    func get_pair_owner(pair_id: felt) -> (pair_owner: felt) {
    }

    func get_reward_token_balance_of_this_contract(pair_id: felt) -> (balance: felt) {
    }

    func get_reward_rate(pair_id: felt) -> (rate: felt) {
    }

    func get_user_info(pair_id: felt) -> (
        balance_of_staked_token: felt, user_reward_per_token_paid: felt, rewards: felt
    ) {
    }

    func earned(user_address: felt, pair_id: felt) -> (earned: felt) {
    }

    func add_token_pair(
        for_stake_token_name: felt,
        for_stake_token_address: felt,
        for_reward_token_name: felt,
        for_reward_token_address: felt,
    ) {
    }

    func set_rewards_duration(duration: felt, pair_id: felt) {
    }

    func set_reward_amount(amount: felt, pair_id: felt) {
    }

    func stake(amount: felt, pair_id: felt) {
    }

    func withdraw(amount: felt, pair_id: felt) {
    }

    func get_reward(pair_id: felt) {
    }

    func get_only_pair_reward_address(pair_id: felt) -> (reward_address: felt) {
    }
}
