import os

import pytest
from starkware.starknet.testing.starknet import Starknet

CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")

@pytest.fixture
async def contract():
    ''''Should be run before every contract'''
    starknet = await Starknet.empty()
    return await starknet.deploy(source=CONTRACT_FILE,)
    

@pytest.mark.asyncio
@pytest.mark.set_owner
async def test_set_owner(contract):
    execution_info = await contract.set_owner(42).invoke()
    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir == 42
