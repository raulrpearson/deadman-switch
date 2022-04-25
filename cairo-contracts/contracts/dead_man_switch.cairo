%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

@storage_var
func owner_heir_storage(owner : felt) -> (heir : felt):
end

@external
func set_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(heir : felt):
    let (caller_address) = get_caller_address()
    owner_heir_storage.write(caller_address, heir)
    return ()
end

@view
func heir_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
    heir : felt
):
    return owner_heir_storage.read(owner)
end
