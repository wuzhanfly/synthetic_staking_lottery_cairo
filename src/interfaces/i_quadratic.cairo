%lang starknet

@contract_interface
namespace IQuadratic {
    func buy_slot(deposit_amount: felt) {
    }

    func sell_slot(withdraw_amount: felt) {
    }

    func add_new_pool(pool_id: felt, proportion_by_100: felt) {
    }

    func get_pool_count() -> (pool_count: felt) {
    }

    func get_user_balance(user_address: felt) -> (user_balance: felt) {
    }

    func get_user_squared_balance(user_address: felt) -> (user_balance: felt) {
    }

    func learn_user_id(user_address: felt) -> (id: felt) {
    }

    func get_idle_id(index: felt) -> (id: felt) {
    }

    func distribute_reward(
        random_number: felt, q_or_n: felt, user_id: felt, balance_tracker: felt
    ) {
    }
}
