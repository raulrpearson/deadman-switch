import os

import pytest
from starkware.starknet.testing.starknet import Starknet

DUMMY_TOKEN_CONTRACT_FILE = os.path.join("contracts", "dummy_token.cairo")
CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")

@pytest.fixture
async def contract():
    ''''Should be run before every contract'''
    starknet = await Starknet.empty()
    dummyToken = await starknet.deploy(source=DUMMY_TOKEN_CONTRACT_FILE,)
    print (dummyToken)
    return await starknet.deploy(source=CONTRACT_FILE,)
    

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir(contract):
    execution_info = await contract.set_heir(42).invoke()
    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir  == 42
