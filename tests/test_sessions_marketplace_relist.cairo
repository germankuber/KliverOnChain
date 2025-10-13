use kliver_on_chain::interfaces::marketplace_interface::{
    IMarketplaceDispatcher, IMarketplaceDispatcherTrait, ListingStatus,
};
use kliver_on_chain::mocks::mock_erc20::MockERC20::IERC20Dispatcher;
use kliver_on_chain::interfaces::kliver_pox::{IKliverPoxDispatcher, IKliverPoxDispatcherTrait};
use kliver_on_chain::components::session_registry_component::SessionMetadata;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn SELLER() -> ContractAddress { 'seller'.try_into().unwrap() }

fn deploy_mock_erc20(to: ContractAddress, amount: u256) -> IERC20Dispatcher {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append('MOCK');
    calldata.append('MCK');
    calldata.append(to.into());
    calldata.append(amount.low.into());
    calldata.append(amount.high.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address: addr }
}

fn deploy_kliver_pox(registry: ContractAddress) -> IKliverPoxDispatcher {
    let contract = declare("KliverPox").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IKliverPoxDispatcher { contract_address: addr }
}

fn deploy_marketplace(
    pox: ContractAddress,
    verifier: ContractAddress,
    token: ContractAddress,
    timeout: u64,
) -> IMarketplaceDispatcher {
    let contract = declare("SessionsMarketplace").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(pox.into());
    calldata.append(verifier.into());
    calldata.append(token.into());
    calldata.append(timeout.into());
    let (addr, _) = contract.deploy(@calldata).unwrap();
    IMarketplaceDispatcher { contract_address: addr }
}

fn mint_session(pox: IKliverPoxDispatcher, registry_addr: ContractAddress, meta: SessionMetadata) {
    start_cheat_caller_address(pox.contract_address, registry_addr);
    pox.mint(meta);
    stop_cheat_caller_address(pox.contract_address);
}

fn deploy_mock_verifier() -> ContractAddress {
    let contract = declare("MockVerifier").unwrap().contract_class();
    let (addr, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    addr
}

#[test]
fn test_relist_after_close_with_new_price() {
    let price1: u256 = 100;
    let price2: u256 = 200;
    let token = deploy_mock_erc20(SELLER(), 0);
    let registry_addr: ContractAddress = 'registry'.try_into().unwrap();
    let pox = deploy_kliver_pox(registry_addr);
    let verifier = deploy_mock_verifier();
    let timeout: u64 = 10;
    let marketplace = deploy_marketplace(pox.contract_address, verifier, token.contract_address, timeout);

    // Mint session for seller
    let meta = SessionMetadata { session_id: 's1', root_hash: 'r1', simulation_id: 'sim1', author: SELLER(), score: 1_u32 };
    mint_session(pox, registry_addr, meta);
    let token_id = pox.get_metadata_by_session('s1').token_id;

    // Create listing1
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.create_listing(token_id, price1);
    
    // Verify first listing is active
    let st1 = marketplace.get_listing_status(token_id);
    assert!(st1 == ListingStatus::Open);
    
    // Close listing1
    marketplace.close_listing(token_id);
    
    // Verify listing is closed
    let st_closed = marketplace.get_listing_status(token_id);
    assert!(st_closed == ListingStatus::Closed);
    
    // Create listing2 with new price (after closing the first)
    marketplace.create_listing(token_id, price2);
    stop_cheat_caller_address(marketplace.contract_address);

    // Verify second listing is open
    let st2 = marketplace.get_listing_status(token_id);
    assert!(st2 == ListingStatus::Open);
}
