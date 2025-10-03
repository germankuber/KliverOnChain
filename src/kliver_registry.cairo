// Import interfaces from separate modules
use crate::character_registry::ICharacterRegistry;
use crate::scenario_registry::IScenarioRegistry;
use crate::simulation_registry::ISimulationRegistry;
use crate::owner_registry::IOwnerRegistry;

/// Kliver Registry Contract
#[starknet::contract]
pub mod kliver_registry {
    use super::{ICharacterRegistry, IScenarioRegistry, ISimulationRegistry, IOwnerRegistry};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, ContractAddress};
    use core::num::traits::Zero;
    

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CharacterVersionRegistered: CharacterVersionRegistered,
        ScenarioRegistered: ScenarioRegistered,
        SimulationRegistered: SimulationRegistered,
    }

    #[derive(Drop, starknet::Event)]
    struct CharacterVersionRegistered {
        #[key]
        character_version_id: felt252,
        character_version_hash: felt252,
        registered_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ScenarioRegistered {
        #[key]
        scenario_id: felt252,
        scenario_hash: felt252,
        registered_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SimulationRegistered {
        #[key]
        simulation_id: felt252,
        simulation_hash: felt252,
        registered_by: ContractAddress,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        paused: bool,
        /// Maps character version ID to its hash
        character_versions: Map<felt252, felt252>,
        /// Maps scenario ID to its hash
        scenarios: Map<felt252, felt252>,
        /// Maps simulation ID to its hash
        simulations: Map<felt252, felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        assert(!owner.is_zero(), 'Owner cannot be zero');
        self.owner.write(owner);
        self.paused.write(false);
    }

    // Character Registry Implementation
    #[abi(embed_v0)]
    impl CharacterRegistryImpl of ICharacterRegistry<ContractState> {
        fn register_character_version(ref self: ContractState, character_version_id: felt252, character_version_hash: felt252) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register character versions
            self._assert_only_owner();
            
            // Validate inputs
            assert(character_version_id != 0, 'Version ID cannot be zero');
            assert(character_version_hash != 0, 'Version hash cannot be zero');
            
            // Check if character version ID is already registered
            let existing_hash = self.character_versions.read(character_version_id);
            assert(existing_hash == 0, 'Version ID already registered');
            
            // Save the character version
            self.character_versions.write(character_version_id, character_version_hash);
            
            // Emit event
            self.emit(CharacterVersionRegistered {
                character_version_id,
                character_version_hash,
                registered_by: get_caller_address()
            });
        }
        
        fn verify_character_version(self: @ContractState, character_version_id: felt252, character_version_hash: felt252) -> bool {
            // Validate inputs
            assert(character_version_id != 0, 'Version ID cannot be zero');
            assert(character_version_hash != 0, 'Version hash cannot be zero');
            
            // Get the stored hash for this character version ID
            let stored_hash = self.character_versions.read(character_version_id);
            
            // Return true if the provided hash matches the stored hash
            stored_hash != 0 && stored_hash == character_version_hash
        }

        fn batch_verify_character_versions(self: @ContractState, character_versions: Array<(felt252, felt252)>) -> Array<(felt252, bool)> {
            let mut results: Array<(felt252, bool)> = ArrayTrait::new();
            let mut i = 0;
            let len = character_versions.len();
            
            while i != len {
                let (character_version_id, character_version_hash) = *character_versions.at(i);
                
                // Skip validation here to avoid panics in batch operations
                // Instead, return false for invalid inputs
                let is_valid = if character_version_id == 0 || character_version_hash == 0 {
                    false
                } else {
                    let stored_hash = self.character_versions.read(character_version_id);
                    stored_hash != 0 && stored_hash == character_version_hash
                };
                
                results.append((character_version_id, is_valid));
                i += 1;
            };
            
            results
        }
        
        fn get_character_version_hash(self: @ContractState, character_version_id: felt252) -> felt252 {
            // Validate input
            assert(character_version_id != 0, 'Version ID cannot be zero');
            
            // Get the stored hash for this character version ID
            let stored_hash = self.character_versions.read(character_version_id);
            
            // If no hash is stored, panic with error
            assert(stored_hash != 0, 'Character version not found');
            
            stored_hash
        }
    }

    // Scenario Registry Implementation
    #[abi(embed_v0)]
    impl ScenarioRegistryImpl of IScenarioRegistry<ContractState> {
        fn register_scenario(ref self: ContractState, scenario_id: felt252, scenario_hash: felt252) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register scenarios
            self._assert_only_owner();
            
            // Validate inputs
            assert(scenario_id != 0, 'Scenario ID cannot be zero');
            assert(scenario_hash != 0, 'Scenario hash cannot be zero');
            
            // Check if scenario is already registered
            let existing_hash = self.scenarios.read(scenario_id);
            assert(existing_hash == 0, 'Scenario already registered');
            
            // Save the scenario
            self.scenarios.write(scenario_id, scenario_hash);
            
            // Emit event
            self.emit(ScenarioRegistered {
                scenario_id,
                scenario_hash,
                registered_by: get_caller_address()
            });
        }
        
        fn verify_scenario(self: @ContractState, scenario_id: felt252, scenario_hash: felt252) -> bool {
            // Validate inputs
            assert(scenario_id != 0, 'Scenario ID cannot be zero');
            assert(scenario_hash != 0, 'Scenario hash cannot be zero');
            
            // Get the stored hash for this scenario ID
            let stored_hash = self.scenarios.read(scenario_id);
            
            // Return true if the provided hash matches the stored hash
            stored_hash != 0 && stored_hash == scenario_hash
        }

        fn batch_verify_scenarios(self: @ContractState, scenarios: Array<(felt252, felt252)>) -> Array<(felt252, bool)> {
            let mut results: Array<(felt252, bool)> = ArrayTrait::new();
            let mut i = 0;
            let len = scenarios.len();
            
            while i != len {
                let (scenario_id, scenario_hash) = *scenarios.at(i);
                
                // Skip validation here to avoid panics in batch operations
                // Instead, return false for invalid inputs
                let is_valid = if scenario_id == 0 || scenario_hash == 0 {
                    false
                } else {
                    let stored_hash = self.scenarios.read(scenario_id);
                    stored_hash != 0 && stored_hash == scenario_hash
                };
                
                results.append((scenario_id, is_valid));
                i += 1;
            };
            
            results
        }
        
        fn get_scenario_hash(self: @ContractState, scenario_id: felt252) -> felt252 {
            // Validate input
            assert(scenario_id != 0, 'Scenario ID cannot be zero');
            
            // Get the stored hash for this scenario ID
            let stored_hash = self.scenarios.read(scenario_id);
            
            // If no hash is stored, panic with error
            assert(stored_hash != 0, 'Scenario not found');
            
            stored_hash
        }
    }

    // Simulation Registry Implementation
    #[abi(embed_v0)]
    impl SimulationRegistryImpl of ISimulationRegistry<ContractState> {
        fn register_simulation(ref self: ContractState, simulation_id: felt252, simulation_hash: felt252) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register simulations
            self._assert_only_owner();
            
            // Validate inputs
            assert(simulation_id != 0, 'Simulation ID cannot be zero');
            assert(simulation_hash != 0, 'Simulation hash cannot be zero');
            
            // Check if simulation is already registered
            let existing_hash = self.simulations.read(simulation_id);
            assert(existing_hash == 0, 'Simulation already registered');
            
            // Save the simulation
            self.simulations.write(simulation_id, simulation_hash);
            
            // Emit event
            self.emit(SimulationRegistered {
                simulation_id,
                simulation_hash,
                registered_by: get_caller_address()
            });
        }
        
        fn verify_simulation(self: @ContractState, simulation_id: felt252, simulation_hash: felt252) -> bool {
            // Validate inputs
            assert(simulation_id != 0, 'Simulation ID cannot be zero');
            assert(simulation_hash != 0, 'Simulation hash cannot be zero');
            
            // Get the stored hash for this simulation ID
            let stored_hash = self.simulations.read(simulation_id);
            
            // Return true if the provided hash matches the stored hash
            stored_hash != 0 && stored_hash == simulation_hash
        }

        fn batch_verify_simulations(self: @ContractState, simulations: Array<(felt252, felt252)>) -> Array<(felt252, bool)> {
            let mut results: Array<(felt252, bool)> = ArrayTrait::new();
            let mut i = 0;
            let len = simulations.len();
            
            while i != len {
                let (simulation_id, simulation_hash) = *simulations.at(i);
                
                // Skip validation here to avoid panics in batch operations
                // Instead, return false for invalid inputs
                let is_valid = if simulation_id == 0 || simulation_hash == 0 {
                    false
                } else {
                    let stored_hash = self.simulations.read(simulation_id);
                    stored_hash != 0 && stored_hash == simulation_hash
                };
                
                results.append((simulation_id, is_valid));
                i += 1;
            };
            
            results
        }
        
        fn get_simulation_hash(self: @ContractState, simulation_id: felt252) -> felt252 {
            // Validate input
            assert(simulation_id != 0, 'Simulation ID cannot be zero');
            
            // Get the stored hash for this simulation ID
            let stored_hash = self.simulations.read(simulation_id);
            
            // If no hash is stored, panic with error
            assert(stored_hash != 0, 'Simulation not found');
            
            stored_hash
        }
    }

    // Owner Registry Implementation
    #[abi(embed_v0)]
    impl OwnerRegistryImpl of IOwnerRegistry<ContractState> {
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
        
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self._assert_only_owner();
            assert(!new_owner.is_zero(), 'New owner cannot be zero');
            self.owner.write(new_owner);
        }
        
        fn pause(ref self: ContractState) {
            self._assert_only_owner();
            self.paused.write(true);
        }
        
        fn unpause(ref self: ContractState) {
            self._assert_only_owner();
            self.paused.write(false);
        }
        
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Not owner');
        }
        
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), 'Contract is paused');
        }
    }
}