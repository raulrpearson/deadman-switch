import os

import pytest
import time
from starkware.starknet.testing.starknet import Starknet

DUMMY_TOKEN_CONTRACT_FILE = os.path.join("contracts", "ERC20", "dummy_token.cairo")
CONTRACT_FILE = os.path.join("contracts", "dead_man_switch.cairo")
OWNER = 12
HEIR = 42


@pytest.fixture
async def starknet():
    return await Starknet.empty()

@pytest.fixture
async def dummy_token_contract(starknet):
    contract = await starknet.deploy(source=DUMMY_TOKEN_CONTRACT_FILE,constructor_calldata=[HEIR, HEIR, 0, 0, HEIR])
    await contract.faucet().invoke(caller_address= OWNER)
    return contract

@pytest.fixture
async def contract(starknet, dummy_token_contract):
    return await starknet.deploy(source=CONTRACT_FILE,constructor_calldata=[dummy_token_contract.contract_address],)
    

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir(dummy_token_contract, contract):
    await dummy_token_contract.approve(contract.contract_address,(100, 00)).invoke(caller_address=HEIR)
    await contract.set_heir(HEIR, 10).invoke(caller_address= OWNER)
    heir_info = await contract.heir_of(OWNER).call()
    assert heir_info.result.heir == HEIR

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_set_heir_not_allowed(contract):
    await dummy_token_contract.approve(contract.contract_address,(0, 0)).invoke(caller_address=HEIR)
    with pytest.raises(Exception) as execution_info:
       await contract.set_heir(HEIR, 10).invoke(caller_address= OWNER)
    assert "Please allow before setting an heir" in execution_info.value.args[1]["message"]

@pytest.mark.asyncio
@pytest.mark.get_allowance
async def test_get_allowance_for(dummy_token_contract, contract):
    await dummy_token_contract.approve(contract.contract_address,(HEIR, HEIR) ).invoke(caller_address=OWNER)
    allowance_info = await contract.get_allowance_for(OWNER).invoke()
    assert allowance_info.result.allowance == (HEIR, HEIR)

@pytest.mark.asyncio
@pytest.mark.get_allowance
async def test_get_allowance_for_zero(contract):
    allowance_info = await contract.get_allowance_for(OWNER).invoke()
    assert allowance_info.result.allowance == (0, 0)


@pytest.mark.asyncio
@pytest.mark.get_allowance
async def test_get_allowance_for_zero(contract):
    allowance_info = await contract.get_allowance_for(OWNER).invoke()
    assert allowance_info.result.allowance == (0, 0)

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_redeem(dummy_token_contract, contract):
    await dummy_token_contract.approve(contract.contract_address,(100, 00)).invoke(caller_address=OWNER)
    await contract.set_heir(HEIR, 10).invoke(caller_address= OWNER)
    await contract.test_set_timestamp(11).invoke()
    balance_info1 = await dummy_token_contract.balanceOf(HEIR).invoke()
    await contract.redeem(OWNER).invoke(caller_address= HEIR)
    balance_info2 = await dummy_token_contract.balanceOf(HEIR).invoke()
    assert balance_info1.result.balance == (0,0)
    assert balance_info2.result.balance == (100,0)

@pytest.mark.asyncio
@pytest.mark.set_heir
async def test_redeem_timestamp_invalid(dummy_token_contract, contract):
    await dummy_token_contract.approve(contract.contract_address,(100, 00)).invoke(caller_address=HEIR)
    await contract.set_heir(HEIR, 10).invoke(caller_address= OWNER)
    await contract.test_set_timestamp(9).invoke()
    balance_info1 = dummy_token_contract.balanceOf(HEIR).invoke()
    heir_info = await contract.redeem(OWNER).call(caller_address= HEIR)
    balance_info2 = dummy_token_contract.balanceOf(HEIR).invoke()
    assert balance_info1.result.balance == (0,0)
    assert balance_info2.result.balance == (100,00)