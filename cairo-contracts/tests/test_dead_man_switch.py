import os

import pytest
from starkware.starknet.testing.starknet import Starknet

DUMMY_TOKEN_CONTRACT_FILE = os.path.join("contracts", "ERC20", "dummy_token.cairo")
CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")

@pytest.fixture
async def contract():
    ''''Should be run before every contract'''
    starknet = await Starknet.empty()
    dummyToken = await starknet.deploy(source=DUMMY_TOKEN_CONTRACT_FILE,constructor_calldata=[42, 42, 0, 0, 42])
    dummyTokenContractAddress = dummyToken.contract_address
    print ("\nContract deployed on:")
    print (dummyTokenContractAddress)
    return await starknet.deploy(source=CONTRACT_FILE,constructor_calldata=[dummyTokenContractAddress],)
    

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir(contract):
    await contract.set_heir(42).invoke()
    heir_info = await contract.heir_of(0).call()
    assert heir_info.result.heir  == 42
