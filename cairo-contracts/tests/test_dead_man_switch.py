import os

import pytest
from starkware.starknet.testing.starknet import Starknet

DUMMY_TOKEN_CONTRACT_FILE = os.path.join("contracts", "ERC20", "dummy_token.cairo")
CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")


@pytest.fixture
async def starknet():
    return await Starknet.empty()

@pytest.fixture
async def dummy_token_contract(starknet):
    return await starknet.deploy(source=DUMMY_TOKEN_CONTRACT_FILE,constructor_calldata=[42, 42, 0, 0, 42])
    
@pytest.fixture
async def contract(starknet, dummy_token_contract):
    return await starknet.deploy(source=CONTRACT_FILE,constructor_calldata=[dummy_token_contract.contract_address],)
    

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir(contract):
    await contract.set_heir(42).invoke(caller_address= 12)
    heir_info = await contract.heir_of(12).call()
    assert heir_info.result.heir == 42

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir_balance_of(dummy_token_contract, contract):
    await contract.set_heir(42).invoke(caller_address=12)
    balance = await dummy_token_contract.allowance(12, contract.contract_address).call()
    assert balance.result.remaining == (0, 0)


