import os
import pytest
from starkware.starknet.testing.starknet import Starknet

DUMMY_TOKEN_CONTRACT_FILE = os.path.join("contracts", "ERC20", "dummy_token.cairo")
CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")
ACCOUNT_FILE = os.path.join("contracts", "Account", "Account.cairo")


@pytest.fixture
async def starknet():
    return await Starknet.empty()

@pytest.fixture
async def dummy_token_contract(starknet):
    return await starknet.deploy(source=DUMMY_TOKEN_CONTRACT_FILE,constructor_calldata=[42, 42, 0, 0, 42])
    
@pytest.fixture
async def contract(starknet, dummy_token_contract):
    return await starknet.deploy(source=CONTRACT_FILE,constructor_calldata=[dummy_token_contract.contract_address],)

@pytest.fixture
async def accounts(starknet):
    owner_pkey = 1235
    heir_pkey = 5421
    owner_account = create_account(starknet, owner_pkey)
    heir_account = create_account(starknet, heir_pkey)
    return [owner_account, heir_account]

async def create_account(starknet, pkey):
    signer = Signer(pkey)
    return await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir(contract, accounts):
    await accounts[0].send_transaction(accounts[0], contract.contract_address, 'set_heir', [42])
    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir  == 42

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir_balance_of(dummy_token_contract, contract, accounts):
    print ("______________________________")
    print (accounts[1])
    await accounts[0].send_transaction(accounts[0], contract.contract_address, 'set_heir', [accounts[1]])
    balance = await dummy_token_contract.allowance(0, contract.contract_address).call()
    assert balance.result.remaining == (0, 0)


@pytest.mark.redeem
async def test_redeem(contract):
    await contract.redeem(0).invoke()
    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir  == 42
