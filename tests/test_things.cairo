%lang starknet

from src.interfaces.i_things_test import IThingsTest

@external
func __setup__() {
    %{ context.things_address = deploy_contract("./src/things_test.cairo").contract_address %}
    return ();
}

@external
func test_all_functions{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    tempvar things_contract_address: felt;
    %{ ids.things_contract_address = context.things_address %}

    let (test) = IThingsTest.index_test(contract_address=things_contract_address);
    assert 0 = test;
    return ();
}
