// SPDX-License-Identifier: MIT
// test_simulation_core.cairo
// Tests for SimulationCore contract

use starknet::{ContractAddress, contract_address_const};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

use kliver_on_chain::simulation_core::{ISimulationCoreDispatcher, ISimulationCoreDispatcherTrait};
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
        fn simulation_exists(ref self: ContractState, simulation_id: felt252) -> bool {
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
    let (core_address, _, _, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    start_cheat_caller_address(core_address, owner);
    core.add_to_whitelist('simulation_1', user);
    stop_cheat_caller_address(core_address);
    
    assert(core.is_whitelisted('simulation_1', user), 'User not whitelisted');
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
    let balance = token.balance_of(user, 'sim_1');
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
#[should_panic(expected: ('Simulation inactive',))]
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
    core.set_active('sim_1', false); // Deactivate
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
    let balance = token.balance_of(user, 'sim_1');
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
    let balance = token.balance_of(user, 'sim_1');
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
#[should_panic(expected: ('Simulation inactive',))]
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
    core.set_active('sim_1', false);
    stop_cheat_caller_address(core_address);
    
    // Try to spend
    start_cheat_caller_address(core_address, user);
    core.spend_tokens('sim_1', 50);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_set_active() {
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
    core.set_active('sim_1', false);
    
    // Reactivate
    core.set_active('sim_1', true);
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: ('Not authorized',))]
fn test_set_active_not_owner() {
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
    
    // Try to set active as non-owner
    start_cheat_caller_address(core_address, non_owner);
    core.set_active('sim_1', false);
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_is_whitelisted_false() {
    let (core_address, _, _, _) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();
    
    assert(!core.is_whitelisted('sim_1', user), 'User should not be whitelisted');
}