use starknet::ContractAddress;

// ============= EVENTS =============
#[derive(Drop, starknet::Event)]
pub struct CharacterVersionRegistered {
    #[key]
    pub character_version_id: felt252,
    pub character_version_hash: felt252,
    pub registered_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ScenarioRegistered {
    #[key]
    pub scenario_id: felt252,
    pub scenario_hash: felt252,
    pub registered_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct SimulationRegistered {
    #[key]
    pub simulation_id: felt252,
    pub simulation_hash: felt252,
    pub registered_by: ContractAddress,
}

/// Character Registry Interface
#[starknet::interface]
pub trait ICharacterRegistry<TContractState> {
    /// Register a character version with its ID and hash (only owner)
    fn register_character_version(ref self: TContractState, character_version_id: felt252, character_version_hash: felt252);
    /// Verify if a character version ID matches its expected hash
    fn verify_character_version(self: @TContractState, character_version_id: felt252, character_version_hash: felt252) -> bool;
    /// Get the hash for a character version ID
    fn get_character_version_hash(self: @TContractState, character_version_id: felt252) -> felt252;
}

/// Scenario Registry Interface
#[starknet::interface]
pub trait IScenarioRegistry<TContractState> {
    /// Register a scenario with its ID and hash (only owner)
    fn register_scenario(ref self: TContractState, scenario_id: felt252, scenario_hash: felt252);
    /// Verify if a scenario ID matches its expected hash
    fn verify_scenario(self: @TContractState, scenario_id: felt252, scenario_hash: felt252) -> bool;
    /// Get the hash for a scenario ID
    fn get_scenario_hash(self: @TContractState, scenario_id: felt252) -> felt252;
}

/// Simulation Registry Interface
#[starknet::interface]
pub trait ISimulationRegistry<TContractState> {
    /// Register a simulation with its ID and hash (only owner)
    fn register_simulation(ref self: TContractState, simulation_id: felt252, simulation_hash: felt252);
    /// Verify if a simulation ID matches its expected hash
    fn verify_simulation(self: @TContractState, simulation_id: felt252, simulation_hash: felt252) -> bool;
    /// Get the hash for a simulation ID
    fn get_simulation_hash(self: @TContractState, simulation_id: felt252) -> felt252;
}

/// Owner Registry Interface
#[starknet::interface]
pub trait IOwnerRegistry<TContractState> {
    /// Get the owner of the contract
    fn get_owner(self: @TContractState) -> ContractAddress;
    /// Transfer ownership to a new address (only current owner)
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    /// Pause the contract (only owner)
    fn pause(ref self: TContractState);
    /// Unpause the contract (only owner)
    fn unpause(ref self: TContractState);
    /// Check if the contract is paused
    fn is_paused(self: @TContractState) -> bool;
}

/// Kliver Registry Contract
#[starknet::contract]
pub mod kliver_registry {
    use super::{
        ICharacterRegistry, IScenarioRegistry, ISimulationRegistry, IOwnerRegistry,
        CharacterVersionRegistered, ScenarioRegistered, SimulationRegistered
    };
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, ContractAddress};
    use core::num::traits::Zero;
    
    // OpenZeppelin imports
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;

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