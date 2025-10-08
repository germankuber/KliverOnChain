// SPDX-License-Identifier: MIT
// test_simulation_core.cairo
// Tests for SimulationCore contract

use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

use kliver_on_chain::simulation_core::{ISimulationCoreDispatcher, ISimulationCoreDispatcherTrait, Simulation};
use kliver_on_chain::{IKliver1155Dispatcher, IKliver1155DispatcherTrait};

// Mock contracts
#[starknet::contract]
mod MockKliverRegistry {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        simulations: Map::<felt252, bool>,
    }

    #[abi(embed_v0)]
    impl MockKliverRegistryImpl of kliver_on_chain::simulation_core::IKliverRegistry<ContractState> {
        fn simulation_exists(self: @ContractState, simulation_id: felt252) -> bool {
            self.simulations.read(simulation_id)
        }
    }

    #[abi(embed_v0)]
    impl MockHelperImpl of MockHelper<ContractState> {
        fn add_simulation(ref self: ContractState, simulation_id: felt252) {
            self.simulations.write(simulation_id, true);
        }
    }

    #[starknet::interface]
    trait MockHelper<TContractState> {
        fn add_simulation(ref self: TContractState, simulation_id: felt252);
    }
}

#[starknet::contract]
mod MockKliver1155 {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        balances: Map::<(ContractAddress, felt252), u256>,
    }

    #[abi(embed_v0)]
    impl MockKliver1155Impl of kliver_on_chain::simulation_core::IKliver1155<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, id: felt252, amount: u256) {
            let current = self.balances.read((to, id));
            self.balances.write((to, id), current + amount);
        }

        fn burn(ref self: ContractState, from: ContractAddress, id: felt252, amount: u256) {
            let current = self.balances.read((from, id));
            assert(current >= amount, 'Insufficient balance');
            self.balances.write((from, id), current - amount);
        }

        fn balance_of(self: @ContractState, owner: ContractAddress, id: felt252) -> u256 {
            self.balances.read((owner, id))
        }
    }
}

// Helper to interact with mock registry
#[starknet::interface]
trait IMockRegistryHelper<TContractState> {
    fn add_simulation(ref self: TContractState, simulation_id: felt252);
}

// Helper functions
fn setup() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let owner: ContractAddress = contract_address_const::<0x123>();
    
    // Deploy mock registry
    let registry_contract = declare("MockKliverRegistry").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();
    
    // Deploy mock token
    let token_contract = declare("MockKliver1155").unwrap().contract_class();
    let (token_address, _) = token_contract.deploy(@array![]).unwrap();
    
    // Deploy SimulationCore
    let core_contract = declare("SimulationCore").unwrap().contract_class();
    let mut constructor_calldata = array![];
    constructor_calldata.append(registry_address.into());
    constructor_calldata.append(token_address.into());
    constructor_calldata.append(owner.into());
    
    let (core_address, _) = core_contract.deploy(@constructor_calldata).unwrap();
    
    (core_address, registry_address, token_address, owner)
}

// ========== TESTS ==========

#[test]
fn test_constructor() {
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    assert(core.get_owner() == owner, 'Wrong owner');
}

#[test]
fn test_register_simulation_success() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    // Add simulation to registry first
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('simulation_1');
    stop_cheat_caller_address(registry_address);
    
    // Register simulation in core
    let daily_amount: u256 = 100;
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('simulation_1', daily_amount);
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not found',))]
fn test_register_simulation_not_in_registry() {
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('nonexistent', 100);
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_register_simulation_not_owner() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let non_owner: ContractAddress = contract_address_const::<0x999>();
    
    // Add simulation to registry
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('simulation_1');
    stop_cheat_caller_address(registry_address);
    
    // Try to register as non-owner
    start_cheat_caller_address(core_address, non_owner);
    core.register_simulation('simulation_1', 100);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_add_to_whitelist() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    let simulation_id = 'simulation_1';
    let daily_amount = 100_u256;
    
    // First register the simulation
    registry.add_simulation(simulation_id);
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id, daily_amount);
    
    // Now add to whitelist
    core.add_to_whitelist(simulation_id, user);
    stop_cheat_caller_address(core_address);
    
    assert(core.is_whitelisted(simulation_id, user), 'User not whitelisted');
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_add_to_whitelist_not_owner() {
    let (core_address, _, _, _) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let non_owner: ContractAddress = contract_address_const::<0x999>();
    let user: ContractAddress = contract_address_const::<0x456>();
    
    start_cheat_caller_address(core_address, non_owner);
    core.add_to_whitelist('simulation_1', user);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_claim_tokens_success() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    let daily_amount: u256 = 100;
    
    // Setup: register simulation
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', daily_amount);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    // Set timestamp
    start_cheat_block_timestamp(core_address, 86400);
    
    // Claim tokens
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    
    stop_cheat_block_timestamp(core_address);
    
    // Verify balance
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data = core.get_simulation_data('sim_1');
    let balance = token.balance_of(user, sim_data.token_id);
    assert(balance == daily_amount, 'Wrong balance');
}

#[test]
#[should_panic(expected: ('Not whitelisted',))]
fn test_claim_tokens_not_whitelisted() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup: register simulation (without whitelisting user)
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    stop_cheat_caller_address(core_address);
    
    // Try to claim
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not active',))]
fn test_claim_tokens_inactive_simulation() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.add_to_whitelist('sim_1', user);
    core.deactivate_simulation('sim_1'); // Deactivate
    stop_cheat_caller_address(core_address);
    
    // Try to claim
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Claim cooldown not passed',))]
fn test_claim_tokens_cooldown_not_passed() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    // First claim
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    
    // Try to claim again immediately (should fail)
    start_cheat_block_timestamp(core_address, 86400 + 1000); // Only 1000 seconds later
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_claim_tokens_after_cooldown() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    let daily_amount: u256 = 100;
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', daily_amount);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    // First claim
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    
    // Second claim after cooldown
    start_cheat_block_timestamp(core_address, 86400 * 2); // 2 days
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Verify balance
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data = core.get_simulation_data('sim_1');
    let balance = token.balance_of(user, sim_data.token_id);
    assert(balance == daily_amount * 2, 'Wrong balance after 2 claims');
}

#[test]
fn test_spend_tokens_success() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    let daily_amount: u256 = 100;
    
    // Setup and claim tokens
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', daily_amount);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    
    // Spend tokens
    let spend_amount: u256 = 50;
    core.spend_tokens('sim_1', spend_amount);
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Verify balance
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data = core.get_simulation_data('sim_1');
    let balance = token.balance_of(user, sim_data.token_id);
    assert(balance == daily_amount - spend_amount, 'Wrong balance after spend');
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_spend_tokens_insufficient_balance() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    
    // Try to spend more than balance
    core.spend_tokens('sim_1', 200);
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not active',))]
fn test_spend_tokens_inactive_simulation() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Deactivate simulation
    start_cheat_caller_address(core_address, owner);
    core.deactivate_simulation('sim_1');
    stop_cheat_caller_address(core_address);
    
    // Try to spend
    start_cheat_caller_address(core_address, user);
    core.spend_tokens('sim_1', 50);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_simulation_state_change() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    
    // Deactivate
    core.deactivate_simulation('sim_1');
    
    // Reactivate
    core.activate_simulation('sim_1');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_deactivate_simulation_not_owner() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let non_owner: ContractAddress = contract_address_const::<0x999>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    stop_cheat_caller_address(core_address);
    
    // Try to deactivate as non-owner
    start_cheat_caller_address(core_address, non_owner);
    core.deactivate_simulation('sim_1');
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_is_whitelisted_false() {
    let (core_address, _, _, _) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    assert(!core.is_whitelisted('sim_1', user), 'User should not be whitelisted');
}

// ===== ADDITIONAL COMPREHENSIVE TESTS =====

#[test]
fn test_register_simulation_zero_daily_amount() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    // Setup simulation in registry
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    // Register simulation with zero daily amount (should work)
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 0);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_register_simulation_large_daily_amount() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    // Setup simulation in registry
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    // Register simulation with large daily amount
    let large_amount: u256 = 1000000000000000000000; // 1000 tokens
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', large_amount);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_multiple_users_whitelist() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user1: ContractAddress = contract_address_const::<0x456>();
    let user2: ContractAddress = contract_address_const::<0x789>();
    let user3: ContractAddress = contract_address_const::<0xabc>();
    
    // Setup simulation in registry
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    
    // Add multiple users to whitelist
    core.add_to_whitelist('sim_1', user1);
    core.add_to_whitelist('sim_1', user2);
    core.add_to_whitelist('sim_1', user3);
    stop_cheat_caller_address(core_address);
    
    // Verify all are whitelisted
    assert(core.is_whitelisted('sim_1', user1), 'User1 not whitelisted');
    assert(core.is_whitelisted('sim_1', user2), 'User2 not whitelisted');
    assert(core.is_whitelisted('sim_1', user3), 'User3 not whitelisted');
}

#[test]
fn test_multiple_simulations() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup multiple simulations in registry
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    registry.add_simulation('sim_2');
    registry.add_simulation('sim_3');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    // Register multiple simulations with different daily amounts
    core.register_simulation('sim_1', 100);
    core.register_simulation('sim_2', 200);
    core.register_simulation('sim_3', 300);
    
    // Whitelist user for all simulations
    core.add_to_whitelist('sim_1', user);
    core.add_to_whitelist('sim_2', user);
    core.add_to_whitelist('sim_3', user);
    stop_cheat_caller_address(core_address);
    
    // Verify whitelisting
    assert(core.is_whitelisted('sim_1', user), 'User not whitelisted for sim_1');
    assert(core.is_whitelisted('sim_2', user), 'User not whitelisted for sim_2');
    assert(core.is_whitelisted('sim_3', user), 'User not whitelisted for sim_3');
}

#[test]
fn test_claim_tokens_different_simulations() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    registry.add_simulation('sim_2');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.register_simulation('sim_2', 200);
    core.add_to_whitelist('sim_1', user);
    core.add_to_whitelist('sim_2', user);
    stop_cheat_caller_address(core_address);
    
    // Claim from both simulations
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    core.claim_tokens('sim_2');
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Verify balances
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data_1 = core.get_simulation_data('sim_1');
    let sim_data_2 = core.get_simulation_data('sim_2');
    let balance1 = token.balance_of(user, sim_data_1.token_id);
    let balance2 = token.balance_of(user, sim_data_2.token_id);
    assert(balance1 == 100, 'Wrong balance for sim_1');
    assert(balance2 == 200, 'Wrong balance for sim_2');
}

#[test]
fn test_spend_tokens_different_simulations() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup and claim tokens
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    registry.add_simulation('sim_2');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.register_simulation('sim_2', 200);
    core.add_to_whitelist('sim_1', user);
    core.add_to_whitelist('sim_2', user);
    stop_cheat_caller_address(core_address);
    
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    core.claim_tokens('sim_2');
    
    // Spend from both simulations
    core.spend_tokens('sim_1', 30);
    core.spend_tokens('sim_2', 50);
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Verify remaining balances
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data_1 = core.get_simulation_data('sim_1');
    let sim_data_2 = core.get_simulation_data('sim_2');
    let balance1 = token.balance_of(user, sim_data_1.token_id);
    let balance2 = token.balance_of(user, sim_data_2.token_id);
    assert(balance1 == 70, 'Wrong remaining balance sim_1');
    assert(balance2 == 150, 'Wrong remaining balance sim_2');
}

#[test]
fn test_simulation_state_and_claim_interaction() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    // Claim when active (should work)
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    
    // Deactivate
    start_cheat_caller_address(core_address, owner);
    core.deactivate_simulation('sim_1');
    stop_cheat_caller_address(core_address);
    
    // Try to claim when inactive (should fail - tested in another test)
    // Reactivate and claim again
    start_cheat_caller_address(core_address, owner);
    core.activate_simulation('sim_1');
    stop_cheat_caller_address(core_address);
    
    start_cheat_block_timestamp(core_address, 86400 * 2);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Verify total balance (2 claims)
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data = core.get_simulation_data('sim_1');
    let balance = token.balance_of(user, sim_data.token_id);
    assert(balance == 200, 'Wrong total balance');
}

#[test]
#[should_panic(expected: ('Simulation not registered',))]
fn test_add_to_whitelist_unregistered_simulation() {
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    start_cheat_caller_address(core_address, owner);
    // Try to whitelist user for unregistered simulation
    core.add_to_whitelist('unregistered_sim', user);
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not registered',))]
fn test_deactivate_simulation_unregistered() {
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    start_cheat_caller_address(core_address, owner);
    // Try to deactivate unregistered simulation
    core.deactivate_simulation('unregistered_sim');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not registered',))]
fn test_claim_tokens_unregistered_simulation() {
    let (core_address, _, _, _) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    start_cheat_caller_address(core_address, user);
    // Try to claim tokens for unregistered simulation
    core.claim_tokens('unregistered_sim');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not registered',))]
fn test_spend_tokens_unregistered_simulation() {
    let (core_address, _, _, _) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    start_cheat_caller_address(core_address, user);
    // Try to spend tokens for unregistered simulation
    core.spend_tokens('unregistered_sim', 50);
    stop_cheat_caller_address(core_address);
}

// Tests for new simulation management methods

#[test]
fn test_is_simulation_registered() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    
    let simulation_id = 'test_sim';
    let daily_amount = 100_u256;
    
    // Initially not registered
    assert(!core.is_simulation_registered(simulation_id), 'Should not be registered');
    
    // Register simulation
    registry.add_simulation(simulation_id);
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id, daily_amount);
    stop_cheat_caller_address(core_address);
    
    // Now should be registered
    assert(core.is_simulation_registered(simulation_id), 'Should be registered');
}

#[test]  
fn test_is_simulation_active() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    
    let simulation_id = 'test_sim';
    let daily_amount = 100_u256;
    
    // Register simulation (active by default)
    registry.add_simulation(simulation_id);
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id, daily_amount);
    
    // Should be active after registration
    assert(core.is_simulation_active(simulation_id), 'Should be active');
    
    // Deactivate simulation
    core.deactivate_simulation(simulation_id);
    assert(!core.is_simulation_active(simulation_id), 'Should be inactive');
    
    // Activate again
    core.activate_simulation(simulation_id);
    assert(core.is_simulation_active(simulation_id), 'Should be active again');
    
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_activate_deactivate_simulation() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    
    let simulation_id = 'test_sim';
    let daily_amount = 100_u256;
    
    // Register simulation
    registry.add_simulation(simulation_id);
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id, daily_amount);
    
    // Initially active
    let sim_data = core.get_simulation_data(simulation_id);
    assert(sim_data.active, 'Should be active initially');
    
    // Deactivate
    core.deactivate_simulation(simulation_id);
    let sim_data = core.get_simulation_data(simulation_id);
    assert(!sim_data.active, 'Should be inactive');
    
    // Activate again
    core.activate_simulation(simulation_id);
    let sim_data = core.get_simulation_data(simulation_id);
    assert(sim_data.active, 'Should be active again');
    
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_token_id_autoincrement() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    
    let simulation_id_1 = 'simulation_1';
    let simulation_id_2 = 'simulation_2';
    let simulation_id_3 = 'simulation_3';
    let daily_amount = 100_u256;
    
    // Register multiple simulations
    registry.add_simulation(simulation_id_1);
    registry.add_simulation(simulation_id_2);
    registry.add_simulation(simulation_id_3);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id_1, daily_amount);
    core.register_simulation(simulation_id_2, daily_amount);
    core.register_simulation(simulation_id_3, daily_amount);
    stop_cheat_caller_address(core_address);
    
    // Verify token IDs are autoincremental starting from 1
    let sim_data_1 = core.get_simulation_data(simulation_id_1);
    let sim_data_2 = core.get_simulation_data(simulation_id_2);
    let sim_data_3 = core.get_simulation_data(simulation_id_3);
    
    assert(sim_data_1.token_id == 1, 'First token ID should be 1');
    assert(sim_data_2.token_id == 2, 'Second token ID should be 2');
    assert(sim_data_3.token_id == 3, 'Third token ID should be 3');
    
    // Verify all other data is correct
    assert(sim_data_1.daily_amount == daily_amount, 'Daily amount should match');
    assert(sim_data_1.active == true, 'Should be active');
}

#[test]
#[should_panic(expected: ('Simulation not registered',))]
fn test_activate_unregistered_simulation() {
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    start_cheat_caller_address(core_address, owner);
    core.activate_simulation('unregistered_sim');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not registered',))]
fn test_deactivate_unregistered_simulation() {
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    
    start_cheat_caller_address(core_address, owner);
    core.deactivate_simulation('unregistered_sim');
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not active',))]
fn test_claim_tokens_from_inactive_simulation() {
    let (core_address, registry_address, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    let simulation_id = 'test_sim';
    let daily_amount = 100_u256;
    
    // Register and deactivate simulation
    registry.add_simulation(simulation_id);
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id, daily_amount);
    core.add_to_whitelist(simulation_id, user);
    core.deactivate_simulation(simulation_id);
    stop_cheat_caller_address(core_address);
    
    // Try to claim tokens from inactive simulation
    start_cheat_caller_address(core_address, user);
    core.claim_tokens(simulation_id);
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Simulation not active',))]
fn test_spend_tokens_from_inactive_simulation() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    let simulation_id = 'test_sim';
    let daily_amount = 100_u256;
    let token_id = 1;
    
    // Register and setup simulation
    registry.add_simulation(simulation_id);
    start_cheat_caller_address(core_address, owner);
    core.register_simulation(simulation_id, daily_amount);
    stop_cheat_caller_address(core_address);
    
    // Give user some tokens
    token.mint(user, token_id, 50_u256);
    
    // Deactivate simulation
    start_cheat_caller_address(core_address, owner);
    core.deactivate_simulation(simulation_id);
    stop_cheat_caller_address(core_address);
    
    // Try to spend tokens from inactive simulation
    start_cheat_caller_address(core_address, user);
    core.spend_tokens(simulation_id, 25_u256);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_balance_of() {
    let (core_address, registry_address, _token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    // Setup simulation
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);
    
    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100);
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);
    
    // Initial balance should be 0
    let initial_balance = core.balance_of('sim_1', user);
    assert(initial_balance == 0, 'Initial balance should be 0');
    
    // Wait for cooldown and claim tokens
    start_cheat_block_timestamp(core_address, 86400);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
    
    // Balance should now be 100
    let balance_after_claim = core.balance_of('sim_1', user);
    assert(balance_after_claim == 100, 'Balance should be 100');
    
    // Spend some tokens
    start_cheat_caller_address(core_address, user);
    core.spend_tokens('sim_1', 30);
    stop_cheat_caller_address(core_address);
    
    // Balance should now be 70
    let balance_after_spend = core.balance_of('sim_1', user);
    assert(balance_after_spend == 70, 'Balance should be 70');
}