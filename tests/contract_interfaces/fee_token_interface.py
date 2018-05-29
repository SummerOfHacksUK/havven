from tests.contract_interfaces.extern_state_token_interface import ExternStateTokenInterface
from utils.deployutils import mine_tx


class FeeTokenInterface(ExternStateTokenInterface):
    def __init__(self, contract, name):
        ExternStateTokenInterface.__init__(self, contract, name)
        
        self.contract = contract
        self.contract_name = name

        self.feePool = lambda: self.contract.functions.feePool().call()
        self.feeAuthority = lambda: self.contract.functions.feeAuthority().call()
        self.transferFeeRate = lambda: self.contract.functions.transferFeeRate().call()

        self.transferFeeIncurred = lambda value: self.contract.functions.transferFeeIncurred(value).call()
        self.transferPlusFee = lambda value: self.contract.functions.transferPlusFee(value).call()
        self.priceToSpend = lambda value: self.contract.functions.priceToSpend(value).call()

        self.setTransferFeeRate = lambda sender, new_fee_rate: mine_tx(
            self.contract.functions.setTransferFeeRate(new_fee_rate).transact({'from': sender}), "setTransferFeeRate", self.contract_name)
        self.setFeeAuthority = lambda sender, new_fee_authority: mine_tx(
            self.contract.functions.setFeeAuthority(new_fee_authority).transact({'from': sender}), "setFeeAuthority", self.contract_name)

        self.withdrawFees = lambda sender, account, value: mine_tx(
            self.contract.functions.withdrawFees(account, value).transact({'from': sender}), "withdrawFees", self.contract_name)
        self.donateToFeePool = lambda sender, value: mine_tx(
            self.contract.functions.donateToFeePool(value).transact({'from': sender}), "donateToFeePool", self.contract_name)

class PublicFeeTokenInterface(FeeTokenInterface):
    def __init__(self, contract, name):
        FeeTokenInterface.__init__(self, contract, name)

        self.clearTokens = lambda sender, address: mine_tx(
            self.contract.functions.clearTokens(address).transact({"from": sender}), "clearTokens", self.contract_name)
        self.giveTokens = lambda sender, address, value: mine_tx(
            self.contract.functions.giveTokens(address, value).transact({"from": sender}), "giveTokens", self.contract_name)