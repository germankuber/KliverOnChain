// Import interfaces from separate modules
use crate::character_registry::ICharacterRegistry;
use crate::scenario_registry::IScenarioRegistry;
use crate::simulation_registry::ISimulationRegistry;
use crate::owner_registry::IOwnerRegistry;
use crate::session_registry::ISessionRegistry;
use crate::types::VerificationResult;

/// Kliver Registry Contract
#[starknet::contract]
pub mod kliver_registry {
    use super::{ICharacterRegistry, IScenarioRegistry, ISimulationRegistry, IOwnerRegistry, ISessionRegistry, VerificationResult};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use core::num::traits::Zero;

    use crate::session_registry::{SessionRegistered, SessionAccessGranted};

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CharacterVersionRegistered: CharacterVersionRegistered,
        ScenarioRegistered: ScenarioRegistered,
        SimulationRegistered: SimulationRegistered,
        SessionRegistered: SessionRegistered,
        SessionAccessGranted: SessionAccessGranted,
    }

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
        // Sessions:
        session_roots: Map<felt252, felt252>,                  // session_id -> root_hash
        session_authors: Map<felt252, ContractAddress>,        // session_id -> author (seller original)
        session_access: Map<(felt252, ContractAddress), bool>, // (session_id, addr) -> true
    }

    pub mod Errors {
        pub const SESSION_ID_CANNOT_BE_ZERO: felt252 = 'Session ID cannot be zero';
        pub const ROOT_HASH_CANNOT_BE_ZERO: felt252 = 'Root hash cannot be zero';
        pub const AUTHOR_CANNOT_BE_ZERO: felt252 = 'Author cannot be zero';
        pub const SESSION_ALREADY_REGISTERED: felt252 = 'Session already registered';
        pub const SESSION_NOT_FOUND: felt252 = 'Session not found';
        pub const GRANTEE_CANNOT_BE_ZERO: felt252 = 'Grantee cannot be zero';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
    ) {
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

        fn verify_character_version(self: @ContractState, character_version_id: felt252, character_version_hash: felt252) -> VerificationResult {
            // Validate inputs
            assert(character_version_id != 0, 'Version ID cannot be zero');
            assert(character_version_hash != 0, 'Version hash cannot be zero');

            // Get the stored hash for this character version ID
            let stored_hash = self.character_versions.read(character_version_id);

            // Determine verification result based on stored data
            if stored_hash == 0 {
                VerificationResult::NotFound  // ID no existe
            } else if stored_hash == character_version_hash {
                VerificationResult::Match     // ID existe y hash coincide
            } else {
                VerificationResult::Mismatch  // ID existe pero hash no coincide
            }
        }

        fn batch_verify_character_versions(self: @ContractState, character_versions: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = character_versions.len();

            while i != len {
                let (character_version_id, character_version_hash) = *character_versions.at(i);

                // For batch operations, handle zero values gracefully instead of panicking
                let verification_result = if character_version_id == 0 || character_version_hash == 0 {
                    VerificationResult::NotFound  // Treat invalid inputs as NotFound
                } else {
                    let stored_hash = self.character_versions.read(character_version_id);

                    if stored_hash == 0 {
                        VerificationResult::NotFound  // ID no existe
                    } else if stored_hash == character_version_hash {
                        VerificationResult::Match     // ID existe y hash coincide
                    } else {
                        VerificationResult::Mismatch  // ID existe pero hash no coincide
                    }
                };

                results.append((character_version_id, verification_result));
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

        fn verify_scenario(self: @ContractState, scenario_id: felt252, scenario_hash: felt252) -> VerificationResult {
            // Validate inputs
            assert(scenario_id != 0, 'Scenario ID cannot be zero');
            assert(scenario_hash != 0, 'Scenario hash cannot be zero');

            // Get the stored hash for this scenario ID
            let stored_hash = self.scenarios.read(scenario_id);

            // Determine verification result based on stored data
            if stored_hash == 0 {
                VerificationResult::NotFound  // ID no existe
            } else if stored_hash == scenario_hash {
                VerificationResult::Match     // ID existe y hash coincide
            } else {
                VerificationResult::Mismatch  // ID existe pero hash no coincide
            }
        }

        fn batch_verify_scenarios(self: @ContractState, scenarios: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = scenarios.len();

            while i != len {
                let (scenario_id, scenario_hash) = *scenarios.at(i);

                // For batch operations, handle zero values gracefully instead of panicking
                let verification_result = if scenario_id == 0 || scenario_hash == 0 {
                    VerificationResult::NotFound  // Treat invalid inputs as NotFound
                } else {
                    let stored_hash = self.scenarios.read(scenario_id);

                    if stored_hash == 0 {
                        VerificationResult::NotFound  // ID no existe
                    } else if stored_hash == scenario_hash {
                        VerificationResult::Match     // ID existe y hash coincide
                    } else {
                        VerificationResult::Mismatch  // ID existe pero hash no coincide
                    }
                };

                results.append((scenario_id, verification_result));
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

        fn verify_simulation(self: @ContractState, simulation_id: felt252, simulation_hash: felt252) -> VerificationResult {
            // Validate inputs
            assert(simulation_id != 0, 'Simulation ID cannot be zero');
            assert(simulation_hash != 0, 'Simulation hash cannot be zero');

            // Get the stored hash for this simulation ID
            let stored_hash = self.simulations.read(simulation_id);

            // Determine verification result based on stored data
            if stored_hash == 0 {
                VerificationResult::NotFound  // ID no existe
            } else if stored_hash == simulation_hash {
                VerificationResult::Match     // ID existe y hash coincide
            } else {
                VerificationResult::Mismatch  // ID existe pero hash no coincide
            }
        }

        fn batch_verify_simulations(self: @ContractState, simulations: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = simulations.len();

            while i != len {
                let (simulation_id, simulation_hash) = *simulations.at(i);

                // For batch operations, handle zero values gracefully instead of panicking
                let verification_result = if simulation_id == 0 || simulation_hash == 0 {
                    VerificationResult::NotFound  // Treat invalid inputs as NotFound
                } else {
                    let stored_hash = self.simulations.read(simulation_id);

                    if stored_hash == 0 {
                        VerificationResult::NotFound  // ID no existe
                    } else if stored_hash == simulation_hash {
                        VerificationResult::Match     // ID existe y hash coincide
                    } else {
                        VerificationResult::Mismatch  // ID existe pero hash no coincide
                    }
                };

                results.append((simulation_id, verification_result));
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

    // Session Registry Implementation
    #[abi(embed_v0)]
    impl SessionRegistryImpl of ISessionRegistry<ContractState> {
        fn register_session(ref self: ContractState, session_id: felt252, root_hash: felt252, author: ContractAddress) {
            self._assert_not_paused();
            self._assert_only_owner(); // Por ahora, sólo Kliver registra

            assert(session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            assert(root_hash != 0, Errors::ROOT_HASH_CANNOT_BE_ZERO);
            assert(!author.is_zero(), Errors::AUTHOR_CANNOT_BE_ZERO);

            let existing = self.session_roots.read(session_id);
            assert(existing == 0, Errors::SESSION_ALREADY_REGISTERED);

            self.session_roots.write(session_id, root_hash);
            self.session_authors.write(session_id, author);

            self.emit(SessionRegistered {
                session_id,
                root_hash,
                author,
                registered_by: get_caller_address()
            });
        }

        fn verify_session(self: @ContractState, session_id: felt252, root_hash: felt252) -> VerificationResult {
            assert(session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            assert(root_hash != 0, Errors::ROOT_HASH_CANNOT_BE_ZERO);

            let stored = self.session_roots.read(session_id);
            if stored == 0 {
                VerificationResult::NotFound
            } else if stored == root_hash {
                VerificationResult::Match
            } else {
                VerificationResult::Mismatch
            }
        }

        fn get_session_info(self: @ContractState, session_id: felt252) -> (felt252, ContractAddress) {
            assert(session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            let root = self.session_roots.read(session_id);
            assert(root != 0, Errors::SESSION_NOT_FOUND);
            let author = self.session_authors.read(session_id);
            (root, author)
        }

        // ---- Opcional: access list (trazabilidad de ventas) ----
        fn grant_access(ref self: ContractState, session_id: felt252, addr: ContractAddress) {
            self._assert_not_paused();
            self._assert_only_owner(); // o permitir también al author si querés: assert(get_caller==owner || == author)

            assert(session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            assert(!addr.is_zero(), Errors::GRANTEE_CANNOT_BE_ZERO);

            let root = self.session_roots.read(session_id);
            assert(root != 0, Errors::SESSION_NOT_FOUND);

            self.session_access.write((session_id, addr), true);

            self.emit(SessionAccessGranted {
                session_id,
                grantee: addr,
                granted_by: get_caller_address()
            });
        }

        fn has_access(self: @ContractState, session_id: felt252, addr: ContractAddress) -> bool {
            self.session_access.read((session_id, addr))
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