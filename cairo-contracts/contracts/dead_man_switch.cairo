%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from contracts.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_le_felt, assert_lt_felt

# ---- Constants

const REDEEM_DEATH_DELAY = 63113904  # 2 years
const MAX_128_BITS_VALUE = 340282366920938463463374607431768211456

# ---- Constructor

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_address : felt
):
    token_to_redeem_address_storage.write(token_address)
    return ()
end

# ---- Events

@event
func HeirRedeemed(heir : felt, owner : felt, amount : Uint256):
end

# ---- Storage vars

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

# --- External functions

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

@external
func redeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt):
    # Check that the caller is indeed an Heir
    let (caller_address) = get_caller_address()
    # assert caller_address = owner_heir_storage.read(owner)

    # Check that the owner is now really 'dead'
    let (current_timestamp) = get_block_timestamp()
    let (owner_last_seen) = owner_last_timestamp_storage.read(owner)
    let time_of_death = owner_last_seen + REDEEM_DEATH_DELAY
    assert_le_felt(time_of_death, current_timestamp)

    # Transfer the total owner's balance
    let (token_to_redeem_address) = token_to_redeem_address_storage.read()
    let (owner_total_balance) = IERC20.balanceOf(token_to_redeem_address, owner)
    IERC20.transfer(token_to_redeem_address, caller_address, owner_total_balance)

    HeirRedeemed.emit(caller_address, owner, owner_total_balance)

    return ()
end

# --- Internal functions

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
