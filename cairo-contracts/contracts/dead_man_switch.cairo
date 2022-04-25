%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from contracts.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256

# Constants
const REDEEM_DEAD_DELAY = 63113904  # 2 years
const MAX_128_BITS_VALUE = 340282366920938463463374607431768211456

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_address : felt
):
    token_to_redeem_address_storage.write(token_address)
    return ()
end

@storage_var
func token_to_redeem_address_storage() -> (token_address):
end

# Could be holding an array of heirs
# Then this could be turned into struct to hold their shares
@storage_var
func owner_heir_storage(owner : felt) -> (heir : felt):
end

@storage_var
func owner_last_timestamp_storage(owner : felt) -> (last_seen : felt):
end

@external
func alive{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller_address) = get_caller_address()
    let (current_timestamp) = get_block_timestamp()
    owner_last_timestamp_storage.write(caller_address, current_timestamp)
    return ()
end

@external
func set_heir{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(heir : felt):
    alloc_locals
    assert 1 = (2 ** 128)
    let (caller_address) = get_caller_address()
    revoke_previous_owner()
    owner_heir_storage.write(caller_address, heir)
    let (token_to_redeem_address) = token_to_redeem_address_storage.read()
    let (approved) = IERC20.approve(
        token_to_redeem_address, heir, Uint256(MAX_128_BITS_VALUE, MAX_128_BITS_VALUE)
    )
    return ()
end

@view
func heir_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
    heir : felt
):
    return owner_heir_storage.read(owner)
end

func revoke_previous_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller_address) = get_caller_address()
    let (heir) = owner_heir_storage.read(caller_address)
    if heir == 0:
        return ()
    end
    let (token_to_redeem_address) = token_to_redeem_address_storage.read()
    let (approved) = IERC20.approve(token_to_redeem_address, heir, Uint256(0, 0))
    with_attr error_message("Issue while revoking the old heir"):
        assert approved = 1
    end
    return ()
end
