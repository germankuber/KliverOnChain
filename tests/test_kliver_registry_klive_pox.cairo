use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

use kliver_on_chain::components::session_registry_component::SessionMetadata;
use kliver_on_chain::components::character_registry_component::CharacterMetadata;
use kliver_on_chain::components::scenario_registry_component::ScenarioMetadata;
use kliver_on_chain::components::simulation_registry_component::SimulationMetadata;
use kliver_on_chain::interfaces::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait};
use kliver_on_chain::interfaces::owner_registry::{IOwnerRegistryDispatcher, IOwnerRegistryDispatcherTrait};
use kliver_on_chain::interfaces::klive_pox::{IKlivePoxDispatcher, IKlivePoxDispatcherTrait};
use kliver_on_chain::interfaces::character_registry::{ICharacterRegistryDispatcher, ICharacterRegistryDispatcherTrait};
use kliver_on_chain::interfaces::scenario_registry::{IScenarioRegistryDispatcher, IScenarioRegistryDispatcherTrait};
use kliver_on_chain::interfaces::simulation_registry::{ISimulationRegistryDispatcher, ISimulationRegistryDispatcherTrait};
use kliver_on_chain::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};

fn OWNER() -> ContractAddress { 'owner'.try_into().unwrap() }
fn AUTHOR() -> ContractAddress { 'author'.try_into().unwrap() }

fn deploy_nft(owner: ContractAddress) -> IKliverNFTDispatcher {
    let cls = declare("KliverNFT").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(owner.into());
    let base_uri: ByteArray = "https://api.kliver.io/nft/";
    Serde::serialize(@base_uri, ref calldata);
    let (addr, _) = cls.deploy(@calldata).unwrap();
    IKliverNFTDispatcher { contract_address: addr }
}

fn deploy_mock_verifier() -> ContractAddress {
    let cls = declare("MockVerifier").unwrap().contract_class();
    let (addr, _) = cls.deploy(@ArrayTrait::new()).unwrap();
    addr
}

fn deploy_registry(nft: ContractAddress, tokens_core: ContractAddress, verifier: ContractAddress) -> ContractAddress {
    let cls = declare("kliver_registry").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(OWNER().into());
    calldata.append(nft.into());
    calldata.append(tokens_core.into());
    calldata.append(verifier.into());
    let (addr, _) = cls.deploy(@calldata).unwrap();
    addr
}

fn deploy_klive_pox(registry: ContractAddress) -> IKlivePoxDispatcher {
    let cls = declare("KlivePox").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    let (addr, _) = cls.deploy(@calldata).unwrap();
    IKlivePoxDispatcher { contract_address: addr }
}

#[test]
fn test_register_session_mints_in_klive_pox_and_verifications() {
    // Deploy dependencies
    let nft = deploy_nft(OWNER());
    let verifier = deploy_mock_verifier();
    // dummy tokens core address
    let tokens_core: ContractAddress = 'tokens_core'.try_into().unwrap();
    // Deploy registry
    let registry_addr = deploy_registry(nft.contract_address, tokens_core, verifier);

    // Deploy KlivePox with registry as authorized minter
    let klive = deploy_klive_pox(registry_addr);

    // Set KlivePox address (only owner)
    let owner_iface = IOwnerRegistryDispatcher { contract_address: registry_addr };
    start_cheat_caller_address(registry_addr, OWNER());
    owner_iface.set_klive_pox_address(klive.contract_address);
    stop_cheat_caller_address(registry_addr);

    // Mint NFT to author so they can register
    start_cheat_caller_address(nft.contract_address, OWNER());
    nft.mint_to_user(AUTHOR());
    stop_cheat_caller_address(nft.contract_address);

    // Register character, scenario, simulation (owner)
    let char_disp = ICharacterRegistryDispatcher { contract_address: registry_addr };
    let scen_disp = IScenarioRegistryDispatcher { contract_address: registry_addr };
    let sim_disp = ISimulationRegistryDispatcher { contract_address: registry_addr };
    start_cheat_caller_address(registry_addr, OWNER());
    char_disp.register_character(CharacterMetadata { character_id: 'char1', character_hash: 'char_hash', author: AUTHOR() });
    scen_disp.register_scenario(ScenarioMetadata { scenario_id: 'scen1', scenario_hash: 'scen_hash', author: AUTHOR() });
    sim_disp.register_simulation(SimulationMetadata { simulation_id: 'sim1', simulation_hash: 'sim_hash', author: AUTHOR(), character_id: 'char1', scenario_id: 'scen1' });
    stop_cheat_caller_address(registry_addr);

    // Register a session via registry (only owner), this mints in KlivePox
    let session = SessionMetadata {
        session_id: 's1',
        root_hash: 'root1',
        simulation_id: 'sim1',
        author: AUTHOR(),
        score: 77_u32,
    };
    let reg_iface = ISessionRegistryDispatcher { contract_address: registry_addr };
    start_cheat_caller_address(registry_addr, OWNER());
    reg_iface.register_session(session);
    stop_cheat_caller_address(registry_addr);

    // Verify KlivePox has the metadata
    let meta = klive.get_metadata_by_session('s1');
    assert!(meta.session_id == 's1', "session id");
    assert!(meta.root_hash == 'root1', "root hash");
    assert!(meta.simulation_id == 'sim1', "sim id");
    assert!(meta.author == AUTHOR(), "author");
    assert!(meta.score == 77_u32, "score");

    // verify_session should match
    let result = reg_iface.verify_session('s1', 'root1');
    match result {
        kliver_on_chain::types::VerificationResult::Match => {},
        _ => assert!(false, "expected match"),
    }

    // verify_complete_session proxies to verifier
    let proof: Array<felt252> = array![1, 2, 3];
    let res = reg_iface.verify_complete_session(proof.span());
    match res {
        Option::Some(_) => {},
        Option::None(()) => assert!(false, "expected Some from verifier"),
    }
}
