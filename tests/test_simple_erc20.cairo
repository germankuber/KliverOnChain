#[cfg(test)]
mod test_simple_erc20 {
    use starknet::ContractAddress;
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    fn OWNER() -> ContractAddress {
        starknet::contract_address_const::<0x123>()
    }

    fn deploy_erc20(
        name: ByteArray, symbol: ByteArray, initial_supply: u256, recipient: ContractAddress
    ) -> ContractAddress {
        let contract = declare("SimpleERC20").unwrap().contract_class();
        let mut constructor_calldata = array![];
        initial_supply.serialize(ref constructor_calldata);
        recipient.serialize(ref constructor_calldata);
        name.serialize(ref constructor_calldata);
        symbol.serialize(ref constructor_calldata);

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        contract_address
    }

    #[test]
    fn test_erc20_deployment() {
        let name = "KliverToken";
        let symbol = "KLVR";
        let initial_supply: u256 = 1000000_u256 * 1000000000000000000_u256; // 1 million tokens
        let recipient = OWNER();

        let token_address = deploy_erc20(name, symbol, initial_supply, recipient);
        let token = IERC20Dispatcher { contract_address: token_address };

        // Test initial supply
        assert(token.total_supply() == initial_supply, 'Invalid total supply');

        // Test recipient balance
        assert(token.balance_of(recipient) == initial_supply, 'Invalid recipient balance');
    }

    #[test]
    fn test_erc20_transfer() {
        let name = "TestToken";
        let symbol = "TEST";
        let initial_supply: u256 = 1000000_u256;
        let sender = OWNER();
        let recipient = starknet::contract_address_const::<0x456>();

        let token_address = deploy_erc20(name, symbol, initial_supply, sender);
        let token = IERC20Dispatcher { contract_address: token_address };

        // Set up the caller to simulate the sender
        start_cheat_caller_address(token_address, sender);

        // Transfer tokens
        let transfer_amount: u256 = 100000_u256;
        token.transfer(recipient, transfer_amount);

        // Verify balances
        assert(
            token.balance_of(sender) == initial_supply - transfer_amount, 'Invalid sender balance'
        );
        assert(token.balance_of(recipient) == transfer_amount, 'Invalid recipient balance');

        stop_cheat_caller_address(token_address);
    }

    #[test]
    fn test_erc20_approve_and_transfer_from() {
        let name = "TestToken";
        let symbol = "TEST";
        let initial_supply: u256 = 1000000_u256;
        let owner = OWNER();
        let spender = starknet::contract_address_const::<0x456>();
        let recipient = starknet::contract_address_const::<0x789>();

        let token_address = deploy_erc20(name, symbol, initial_supply, owner);
        let token = IERC20Dispatcher { contract_address: token_address };

        // Owner approves spender
        start_cheat_caller_address(token_address, owner);
        let approve_amount: u256 = 100000_u256;
        token.approve(spender, approve_amount);
        stop_cheat_caller_address(token_address);

        // Verify allowance
        assert(token.allowance(owner, spender) == approve_amount, 'Invalid allowance');

        // Spender transfers from owner to recipient
        start_cheat_caller_address(token_address, spender);
        let transfer_amount: u256 = 50000_u256;
        token.transfer_from(owner, recipient, transfer_amount);
        stop_cheat_caller_address(token_address);

        // Verify balances and allowance
        assert(
            token.balance_of(owner) == initial_supply - transfer_amount, 'Invalid owner balance'
        );
        assert(token.balance_of(recipient) == transfer_amount, 'Invalid recipient balance');
        assert(
            token.allowance(owner, spender) == approve_amount - transfer_amount,
            'Invalid remaining allowance'
        );
    }
}
