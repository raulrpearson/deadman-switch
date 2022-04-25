%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from contracts.ERC20.IERC20 import IERC20
from starkware.cairo.common.uint256 import Uint256, uint256_lt
from starkware.cairo.common.math import assert_le_felt, assert_lt_felt

# ---- Constants

const MAX_128_BITS_VALUE = 340282366920938463463374607431768211455

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
func OwnerNotDead(owner : felt):
end

@event
func HeirRedeemed(heir : felt, owner : felt, amount : Uint256):
end

@event
func HeirSet(heir : felt, owner : felt, delay : felt):
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
func owner_delay_storage(owner : felt) -> (delay : felt):
end

@storage_var
func owner_last_timestamp_storage(owner : felt) -> (last_seen : felt):
end

# ---- Views
@view
func time_until_death{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt
) -> (time_left : felt):
    let (redeem_death_delay) = owner_delay_storage.read(owner)
    let (owner_last_seen) = owner_last_timestamp_storage.read(owner)
    let time_of_death = owner_last_seen + redeem_death_delay
    let (block_timestamp) = get_block_timestamp()
    let time_left = time_of_death - block_timestamp
    return (time_left)
end

@view
func owner_last_seen{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt
) -> (last_seen : felt):
    return owner_last_timestamp_storage.read(owner)
end

@view
func token_to_redeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    token_address : felt
):
    return token_to_redeem_address_storage.read()
end

@view
func heir_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
    heir : felt
):
    return owner_heir_storage.read(owner)
end

@view
func delay_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
    delay : felt
):
    return owner_delay_storage.read(owner)
end

@view
func get_allowance_for{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    heir : felt
) -> (allowance : Uint256):
    let (token_address) = token_to_redeem_address_storage.read()
    let (contract_address) = get_contract_address()
    let (allowance) = IERC20.allowance(token_address, heir, contract_address)
    return (allowance)
end

# --- External functions

@external
func alive{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (caller_address) = get_caller_address()
    let (current_timestamp) = get_block_timestamp()
    owner_last_timestamp_storage.write(caller_address, current_timestamp)

    OwnerNotDead.emit(caller_address)

    return ()
end

@external
func set_heir{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    heir : felt, delay : felt
):
    alloc_locals
    checkAllowanceFor(heir)
    let (caller_address) = get_caller_address()
    let (contract_address) = get_contract_address()
    revoke_previous_owner()
    owner_heir_storage.write(caller_address, heir)
    owner_delay_storage.write(caller_address, delay)
    HeirSet.emit(caller_address, heir, delay)

    return ()
end

@external
func redeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt):
    # Check that the caller is indeed an Heir
    let (caller_address) = get_caller_address()
    # assert caller_address = owner_heir_storage.read(owner)

    # Check that the owner is now really 'dead'
    let (current_timestamp) = get_block_timestamp()
    let (owner_last_seen) = owner_last_timestamp_storage.read(owner)
    let (redeem_death_delay) = owner_delay_storage.read(caller_address)
    let time_of_death = owner_last_seen + redeem_death_delay
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

func checkAllowanceFor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    heir : felt
):
    alloc_locals
    let (allowance) = get_allowance_for(heir)
    let oneAsUint256 = Uint256(1, 0)
    let (is_zero) = uint256_lt(allowance, oneAsUint256)
    with_attr error_message("Please allow before setting an heir"):
        assert is_zero = 0
    end
    return ()
end
