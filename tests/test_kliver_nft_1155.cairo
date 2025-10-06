use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
use starknet::ContractAddress;

// Import ERC1155 interfaces
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

// Import Kliver NFT 1155 interface
use kliver_on_chain::kliver_nft_1155::{IKliverNFT1155Dispatcher, IKliverNFT1155DispatcherTrait};

// Mock ERC1155Receiver contract for testing
#[starknet::contract]
mod MockERC1155Receiver {
    use openzeppelin::token::erc1155::interface::IERC1155Receiver;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState) {
        // SRC5 component doesn't need manual initialization in newer versions
    }
    
    #[abi(embed_v0)]
    impl ERC1155ReceiverImpl of IERC1155Receiver<ContractState> {
        fn on_erc1155_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) -> felt252 {
            // Return the magic value indicating acceptance
            0x4e2312e0
        }
        
        fn on_erc1155_batch_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) -> felt252 {
            // Return the magic value indicating acceptance
            0x4e2312e0
        }
    }
}

/// Helper function to deploy a mock ERC1155Receiver contract
fn deploy_mock_receiver() -> ContractAddress {
    let contract = declare("MockERC1155Receiver").unwrap().contract_class();
    let constructor_calldata = array![];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

/// Helper function to deploy the NFT 1155 contract
fn deploy_nft_1155_contract() -> (IKliverNFT1155Dispatcher, IERC1155Dispatcher, IOwnableDispatcher, ContractAddress) {
    let owner: ContractAddress = starknet::contract_address_const::<0x123>();
    let contract = declare("KliverNFT1155").unwrap().contract_class();
    
    // Constructor calldata: owner, base_uri
    let base_uri: ByteArray = "https://api.kliver.com/metadata/";
    let mut constructor_calldata = array![];
    owner.serialize(ref constructor_calldata);
    base_uri.serialize(ref constructor_calldata);
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    
    let kliver_dispatcher = IKliverNFT1155Dispatcher { contract_address };
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    
    (kliver_dispatcher, erc1155_dispatcher, ownable_dispatcher, owner)
}

/// Test contract deployment and initial state
#[test]
fn test_deploy_contract() {
    let (_kliver_dispatcher, erc1155_dispatcher, ownable_dispatcher, expected_owner) = deploy_nft_1155_contract();
    
    // Check owner is set correctly
    let actual_owner = ownable_dispatcher.owner();
    assert(actual_owner == expected_owner, 'Wrong owner');
    
    // Check ERC1155 interface works
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let balance = erc1155_dispatcher.balance_of(user, 1);
    assert(balance == 0, 'Initial balance should be 0');
}

/// Test adding a new token type (only owner)
#[test]
fn test_add_token_type() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    let token_id: u256 = 101;  // Use unique ID
    let max_supply: u256 = 1000;
    let is_soulbound = false;
    let metadata_uri: ByteArray = "character/warrior.json";
    
    kliver_dispatcher.add_token_type(token_id, max_supply, is_soulbound, metadata_uri.clone());
    
    // Verify token type was added
    let retrieved_metadata = kliver_dispatcher.get_token_metadata(token_id);
    assert(retrieved_metadata == metadata_uri, 'Metadata mismatch');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test adding token type fails for non-owner
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_add_token_type_fails_non_owner() {
    let (kliver_dispatcher, _, _, _) = deploy_nft_1155_contract();
    
    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();
    start_cheat_caller_address(kliver_dispatcher.contract_address, not_owner);
    
    kliver_dispatcher.add_token_type(1, 1000, false, "test.json");
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test minting tokens to a user
#[test]
fn test_mint_to_user() {
    let (kliver_dispatcher, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type first
    let token_id: u256 = 102;
    let max_supply: u256 = 1000;
    kliver_dispatcher.add_token_type(token_id, max_supply, false, "warrior.json");
    
    // Mint tokens using unsafe method for EOA testing
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let amount: u256 = 5;
    
    kliver_dispatcher.mint_to_user_unsafe(user, token_id, amount);
    
    // Verify mint
    let balance = erc1155_dispatcher.balance_of(user, token_id);
    assert(balance == amount, 'Wrong balance after mint');
    
    let user_balance = kliver_dispatcher.get_user_balance(user, token_id);
    assert(user_balance == amount, 'Wrong user balance');
    
    let has_token = kliver_dispatcher.user_has_token(user, token_id);
    assert(has_token == true, 'User should have token');
    
    let total_supply = kliver_dispatcher.total_supply(token_id);
    assert(total_supply == amount, 'Wrong total supply');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test minting fails for non-owner
#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_fails_non_owner() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    // Setup token type as owner
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    kliver_dispatcher.add_token_type(103, 1000, false, "test.json");
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
    
    // Try to mint as non-owner
    let not_owner: ContractAddress = 'not_owner'.try_into().unwrap();
    start_cheat_caller_address(kliver_dispatcher.contract_address, not_owner);
    
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    kliver_dispatcher.mint_to_user(user, 103, 5);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test batch minting
#[test]
fn test_batch_mint_to_user() {
    let (kliver_dispatcher, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add multiple token types
    kliver_dispatcher.add_token_type(104, 1000, false, "warrior.json");
    kliver_dispatcher.add_token_type(105, 500, false, "mage.json");
    kliver_dispatcher.add_token_type(106, 200, true, "legendary.json");
    
    // Batch mint
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let token_ids = array![104, 105, 106].span();
    let amounts = array![10, 5, 1].span();
    
    kliver_dispatcher.batch_mint_to_user_unsafe(user, token_ids, amounts);
    
    // Verify batch mint
    let balance1 = erc1155_dispatcher.balance_of(user, 104);
    let balance2 = erc1155_dispatcher.balance_of(user, 105);
    let balance3 = erc1155_dispatcher.balance_of(user, 106);
    
    assert(balance1 == 10, 'Wrong balance for token 104');
    assert(balance2 == 5, 'Wrong balance for token 105');
    assert(balance3 == 1, 'Wrong balance for token 106');
    
    // Check total supplies
    assert(kliver_dispatcher.total_supply(104) == 10, 'Wrong total supply 104');
    assert(kliver_dispatcher.total_supply(105) == 5, 'Wrong total supply 105');
    assert(kliver_dispatcher.total_supply(106) == 1, 'Wrong total supply 106');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test batch mint with mismatched arrays fails
#[test]
#[should_panic(expected: ('Invalid array length',))]
fn test_batch_mint_arrays_length_mismatch() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    kliver_dispatcher.add_token_type(107, 1000, false, "test.json");
    
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let token_ids = array![107, 108].span();  // 2 elements
    let amounts = array![10].span();      // 1 element (mismatch!)
    
    kliver_dispatcher.batch_mint_to_user_unsafe(user, token_ids, amounts);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test burning tokens
#[test]
fn test_burn_user_tokens() {
    let (kliver_dispatcher, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Setup and mint
    kliver_dispatcher.add_token_type(108, 1000, false, "warrior.json");
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    kliver_dispatcher.mint_to_user_unsafe(user, 108, 10);
    
    // Burn some tokens
    kliver_dispatcher.burn_user_tokens(user, 108, 3);
    
    // Verify burn
    let balance = erc1155_dispatcher.balance_of(user, 108);
    assert(balance == 7, 'Wrong balance after burn');
    
    let total_supply = kliver_dispatcher.total_supply(108);
    assert(total_supply == 7, 'Wrong total supply after burn');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test burning more tokens than owned fails
#[test]
#[should_panic]
fn test_burn_exceeds_balance() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Setup and mint
    kliver_dispatcher.add_token_type(109, 1000, false, "warrior.json");
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    kliver_dispatcher.mint_to_user_unsafe(user, 109, 5);
    
    // Try to burn more than owned
    kliver_dispatcher.burn_user_tokens(user, 109, 10);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test soulbound tokens cannot be transferred
#[test]
#[should_panic(expected: ('Soulbound token transfer',))]
fn test_soulbound_transfer_blocked() {
    let (kliver_dispatcher, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Create soulbound token
    kliver_dispatcher.add_token_type(110, 1000, true, "soulbound.json");
    let user1: ContractAddress = starknet::contract_address_const::<0x456>();
    kliver_dispatcher.mint_to_user_unsafe(user1, 110, 1);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
    
    // Try to transfer soulbound token (should fail)
    start_cheat_caller_address(kliver_dispatcher.contract_address, user1);
    
    let user2: ContractAddress = starknet::contract_address_const::<0x789>();
    kliver_dispatcher.safe_transfer_from_unsafe(user1, user2, 110, 1);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test regular tokens can be transferred
#[test]
fn test_regular_token_transfer() {
    let (kliver_dispatcher, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Create regular (non-soulbound) token
    kliver_dispatcher.add_token_type(111, 1000, false, "transferable.json");
    let user1: ContractAddress = starknet::contract_address_const::<0x456>();
    kliver_dispatcher.mint_to_user_unsafe(user1, 111, 5);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
    
    // Transfer tokens
    start_cheat_caller_address(kliver_dispatcher.contract_address, user1);
    
    let user2: ContractAddress = starknet::contract_address_const::<0x789>();
    kliver_dispatcher.safe_transfer_from_unsafe(user1, user2, 111, 2);
    
    // Verify transfer
    let balance1 = erc1155_dispatcher.balance_of(user1, 111);
    let balance2 = erc1155_dispatcher.balance_of(user2, 111);
    
    assert(balance1 == 3, 'Wrong sender balance');
    assert(balance2 == 2, 'Wrong receiver balance');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test ERC1155 batch balance query
#[test]
fn test_batch_balance_of() {
    let (kliver_dispatcher, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Setup multiple token types and users
    kliver_dispatcher.add_token_type(112, 1000, false, "warrior.json");
    kliver_dispatcher.add_token_type(113, 500, false, "mage.json");
    
    let user1: ContractAddress = starknet::contract_address_const::<0x456>();
    let user2: ContractAddress = starknet::contract_address_const::<0x789>();
    
    kliver_dispatcher.mint_to_user_unsafe(user1, 112, 10);
    kliver_dispatcher.mint_to_user_unsafe(user1, 113, 5);
    kliver_dispatcher.mint_to_user_unsafe(user2, 112, 3);
    kliver_dispatcher.mint_to_user_unsafe(user2, 113, 7);
    
    // Test batch balance query
    let owners = array![user1, user1, user2, user2].span();
    let token_ids = array![112, 113, 112, 113].span();
    let balances = erc1155_dispatcher.balance_of_batch(owners, token_ids);
    
    assert(*balances.at(0) == 10, 'Wrong batch balance 0');
    assert(*balances.at(1) == 5, 'Wrong batch balance 1');
    assert(*balances.at(2) == 3, 'Wrong batch balance 2');
    assert(*balances.at(3) == 7, 'Wrong batch balance 3');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test metadata URI functionality
#[test]
fn test_metadata_uri() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    let token_id: u256 = 114;
    let metadata_uri: ByteArray = "characters/epic_warrior.json";
    
    kliver_dispatcher.add_token_type(token_id, 1000, false, metadata_uri.clone());
    
    let retrieved_uri = kliver_dispatcher.get_token_metadata(token_id);
    assert(retrieved_uri == metadata_uri, 'Metadata URI mismatch');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test zero balance user_has_token
#[test]
fn test_user_has_token_zero_balance() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    kliver_dispatcher.add_token_type(115, 1000, false, "test.json");
    
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    let has_token = kliver_dispatcher.user_has_token(user, 115);
    
    assert(has_token == false, 'User should not have token');
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test with timestamp manipulation
#[test]
fn test_with_timestamp() {
    let timestamp: u64 = 1000000;
    start_cheat_block_timestamp_global(timestamp);
    
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type and mint (events should include timestamp)
    kliver_dispatcher.add_token_type(116, 1000, false, "timestamped.json");
    
    let user: ContractAddress = starknet::contract_address_const::<0x456>();
    kliver_dispatcher.mint_to_user_unsafe(user, 116, 1);
    
    // The events should be emitted with the mocked timestamp
    // This test mainly verifies the contract works with timestamp manipulation
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
    stop_cheat_block_timestamp_global();
}

/// Test total_supply function
#[test]
fn test_total_supply() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type
    kliver_dispatcher.add_token_type(200, 1000, false, "supply.json");
    
    // Initially should be zero
    assert_eq!(kliver_dispatcher.total_supply(200), 0);
    
    // Mint to users
    let user1: ContractAddress = 'user1'.try_into().unwrap();
    let user2: ContractAddress = 'user2'.try_into().unwrap();
    
    kliver_dispatcher.mint_to_user_unsafe(user1, 200, 10);
    assert_eq!(kliver_dispatcher.total_supply(200), 10);
    
    kliver_dispatcher.mint_to_user_unsafe(user2, 200, 15);
    assert_eq!(kliver_dispatcher.total_supply(200), 25);
    
    // Burn some tokens
    kliver_dispatcher.burn_user_tokens(user1, 200, 3);
    assert_eq!(kliver_dispatcher.total_supply(200), 22);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test get_token_metadata function
#[test]
fn test_get_token_metadata() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type with metadata
    let metadata = "https://example.com/metadata/201.json";
    kliver_dispatcher.add_token_type(201, 1000, false, metadata);
    
    // Get metadata
    let retrieved_metadata = kliver_dispatcher.get_token_metadata(201);
    assert_eq!(retrieved_metadata, "https://example.com/metadata/201.json");
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test get_user_balance function
#[test]
fn test_get_user_balance() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type
    kliver_dispatcher.add_token_type(202, 1000, false, "balance.json");
    
    let user: ContractAddress = 'user'.try_into().unwrap();
    
    // Initially should be zero
    assert_eq!(kliver_dispatcher.get_user_balance(user, 202), 0);
    
    // Mint tokens
    kliver_dispatcher.mint_to_user_unsafe(user, 202, 25);
    assert_eq!(kliver_dispatcher.get_user_balance(user, 202), 25);
    
    // Burn some tokens
    kliver_dispatcher.burn_user_tokens(user, 202, 5);
    assert_eq!(kliver_dispatcher.get_user_balance(user, 202), 20);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test add_token_type with duplicate token_id should fail
#[test]
#[should_panic(expected: ('Token type already exists', ))]
fn test_add_token_type_duplicate() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type
    kliver_dispatcher.add_token_type(203, 1000, false, "first.json");
    
    // Try to add same token_id again (should fail)
    kliver_dispatcher.add_token_type(203, 500, true, "second.json");
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test add_token_type with zero max_supply
#[test]
fn test_add_token_type_zero_max_supply() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type with zero max supply (should be allowed)
    kliver_dispatcher.add_token_type(204, 0, false, "zero_supply.json");
    
    // Verify it was added
    let metadata = kliver_dispatcher.get_token_metadata(204);
    assert_eq!(metadata, "zero_supply.json");
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test mint_to_user with max_supply (currently not enforced - TODO in contract)
#[test]
fn test_mint_with_max_supply_todo() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type with limited supply
    kliver_dispatcher.add_token_type(205, 10, false, "limited.json");
    
    let user: ContractAddress = 'user'.try_into().unwrap();
    
    // Currently this passes because max_supply validation is TODO in contract
    kliver_dispatcher.mint_to_user_unsafe(user, 205, 15);
    
    // Verify tokens were minted (contract doesn't enforce max_supply yet)
    assert_eq!(kliver_dispatcher.get_user_balance(user, 205), 15);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test burn_user_tokens with insufficient balance
#[test]
#[should_panic(expected: ('Insufficient balance', ))]
fn test_burn_insufficient_balance() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type
    kliver_dispatcher.add_token_type(206, 1000, false, "burn_test.json");
    
    let user: ContractAddress = 'user'.try_into().unwrap();
    
    // Mint some tokens
    kliver_dispatcher.mint_to_user_unsafe(user, 206, 5);
    
    // Try to burn more than user has (should fail)
    kliver_dispatcher.burn_user_tokens(user, 206, 10);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test individual balance_of function from ERC1155
#[test]
fn test_balance_of_individual() {
    let (_, erc1155_dispatcher, _, owner) = deploy_nft_1155_contract();
    let kliver_dispatcher = IKliverNFT1155Dispatcher { contract_address: erc1155_dispatcher.contract_address };
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type
    kliver_dispatcher.add_token_type(207, 1000, false, "individual.json");
    
    let user: ContractAddress = 'user'.try_into().unwrap();
    
    // Initially should be zero
    assert_eq!(erc1155_dispatcher.balance_of(user, 207), 0);
    
    // Mint tokens
    kliver_dispatcher.mint_to_user_unsafe(user, 207, 30);
    assert_eq!(erc1155_dispatcher.balance_of(user, 207), 30);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test approval functions are disabled
#[test]
#[should_panic(expected: ('Approvals disabled', ))]
fn test_approval_functions_disabled() {
    let (_, erc1155_dispatcher, _, _) = deploy_nft_1155_contract();
    
    let user: ContractAddress = 'user'.try_into().unwrap();
    let operator: ContractAddress = 'operator'.try_into().unwrap();
    
    start_cheat_caller_address(erc1155_dispatcher.contract_address, user);
    
    // Try to set approval (should fail - approvals are disabled)
    erc1155_dispatcher.set_approval_for_all(operator, true);
    
    stop_cheat_caller_address(erc1155_dispatcher.contract_address);
}

/// Test safe_transfer_from_unsafe allows transfers (it's unsafe for testing)
#[test]
fn test_safe_transfer_unsafe_works() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type
    kliver_dispatcher.add_token_type(208, 1000, false, "transfer_test.json");
    
    let user1: ContractAddress = 'user1'.try_into().unwrap();
    let user2: ContractAddress = 'user2'.try_into().unwrap();
    
    // Mint tokens to user1
    kliver_dispatcher.mint_to_user_unsafe(user1, 208, 10);
    
    // Verify user1 has tokens
    assert_eq!(kliver_dispatcher.get_user_balance(user1, 208), 10);
    assert_eq!(kliver_dispatcher.get_user_balance(user2, 208), 0);
    
    // Use unsafe transfer (should work - it's designed for testing)
    kliver_dispatcher.safe_transfer_from_unsafe(user1, user2, 208, 5);
    
    // Verify transfer worked
    assert_eq!(kliver_dispatcher.get_user_balance(user1, 208), 5);
    assert_eq!(kliver_dispatcher.get_user_balance(user2, 208), 5);
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}

/// Test URI function through get_token_metadata
#[test]
fn test_uri_function() {
    let (kliver_dispatcher, _, _, owner) = deploy_nft_1155_contract();
    
    start_cheat_caller_address(kliver_dispatcher.contract_address, owner);
    
    // Add token type with metadata URI
    kliver_dispatcher.add_token_type(209, 1000, false, "https://api.kliver.io/metadata/209.json");
    
    // Get URI through Kliver interface
    let uri = kliver_dispatcher.get_token_metadata(209);
    assert_eq!(uri, "https://api.kliver.io/metadata/209.json");
    
    stop_cheat_caller_address(kliver_dispatcher.contract_address);
}