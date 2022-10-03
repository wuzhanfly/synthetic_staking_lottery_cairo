%lang starknet
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

// #aynı anda stake veya withdraw olunca tam olarak neler oluyor, blocktimestamp nasıl çalışıyor?


@contract_interface
namespace IStaking {
    func add_token_pair(
        for_stake_token_name: felt,
        for_stake_token_address: felt,
        for_reward_token_name: felt,
        for_reward_token_address: felt,) {
    }

    func set_rewards_duration(duration: felt, pair_id: felt) {
    }

    func last_pair_id_storage() -> (last_pair_id: felt) {
    }
}


@external
func test_staking_contract{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    local staking_contract_address: felt;
    local staking_token_address: felt;
    local reward_token_address: felt;

    %{ ids.staking_contract_address = deploy_contract("./src/staking.cairo").contract_address %} 
    %{ ids.staking_token_address = deploy_contract("./src/staking_token.cairo").contract_address %} 
    %{ ids.reward_token_address = deploy_contract("./src/reward_token.cairo").contract_address %}
    
    IStaking.add_token_pair(staking_contract_address,15,staking_token_address,30,reward_token_address);

    let (id) = IStaking.last_pair_id_storage(contract_address=staking_contract_address);
    assert id = 1;

    //IStaking.set_rewards_duration(staking_contract_address, 1515, 1);

    return ();
}

@contract_interface
namespace IERC20 {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (totalSupply: Uint256) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func owner() -> (owner: felt) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (success: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (success: felt) {
    }

    func burn(amount: Uint256) {
    }

    func transferOwnership(newOwner: felt) {
    }

    func renounceOwnership() {
    }

    func mint(to: felt, amount: Uint256) {
    }
}
