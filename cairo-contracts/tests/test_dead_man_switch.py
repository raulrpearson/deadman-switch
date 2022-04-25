import os
import pytest
from starkware.starknet.testing.starknet import Starknet, Signer

DUMMY_TOKEN_CONTRACT_FILE = os.path.join("contracts", "ERC20", "dummy_token.cairo")
CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")
ACCOUNT_FILE = os.path.join("contracts", "Account", "Account.cairo")

@pytest.fixture
async def contract():
    ''''Should be run before every contract'''
    starknet = await Starknet.empty()
    dummyToken = await starknet.deploy(source=DUMMY_TOKEN_CONTRACT_FILE,constructor_calldata=[42, 42, 0, 0, 42])
    dummyTokenContractAddress = dummyToken.contract_address

    print ("\nContract deployed on:")
    print (dummyTokenContractAddress)
    return await starknet.deploy(source=CONTRACT_FILE,constructor_calldata=[dummyTokenContractAddress],)

async def create_account(pkey):
    signer = Signer(pkey)
    starknet = await Starknet.empty()

    # 1. Deploy Account
    return await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

@pytest.fixture
async def accounts():
    owner_pkey = 1235
    heir_pkey = 5421
    owner_account = create_account(owner_pkey)
    heir_account = create_account(heir_pkey)
    return [owner_account, heir_account]

# 2. Send transaction through Account
    #

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir(contract):
    await contract.set_heir(42).invoke()

    # TODO: we need to also have this signer available
    await signer.send_transaction(account, some_contract_address, 'some_function', [some_parameter])

    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir  == 42

@pytest.mark.asyncio
@pytest.mark.redeem
async def test_redeem(contract):
    await contract.redeem(0).invoke()
    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir  == 42