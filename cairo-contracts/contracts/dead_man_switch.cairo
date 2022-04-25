%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from contracts.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256

# Constants
const REDEEM_DEAD_DELAY = 63113904  # 2 years
const TOKEN_TO_REDEEM = 42  # To be defined

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
    let (caller_address) = get_caller_address()
    revoke_previous_owner()
    owner_heir_storage.write(caller_address, heir)
    let (approved) = IERC20.approve(TOKEN_TO_REDEEM, heir, Uint256(0, 0))
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
    let (approved) = IERC20.approve(TOKEN_TO_REDEEM, heir, Uint256(0, 0))
    with_attr error_message("Issue while revoking the old heir"):
        assert approved = 1
    end
    return ()
end
