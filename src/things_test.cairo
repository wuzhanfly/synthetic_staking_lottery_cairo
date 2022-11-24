%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func idle_ids_storage(index: felt) -> (idle_id: felt) {
}

@storage_var
func last_idle_id_index_storage() -> (last_idle_id_index: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    last_idle_id_index_storage.write(1);
    // idle_ids_storage.write(1,1); //index starts from 1-1
    return ();
}

@external
func index_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (id: felt) {
    let (idle_id_index) = last_idle_id_index_storage.read();
    let (idle_id) = idle_ids_storage.read(index=idle_id_index);
    return (id=idle_id);
}
