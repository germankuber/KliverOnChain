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

    use crate::session_registry::{SessionAccessGranted, SessionMetadata};
    use crate::simulation_registry::SimulationMetadata;
    use crate::character_registry::CharacterMetadata;
    use crate::scenario_registry::ScenarioMetadata;
    use crate::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CharacterVersionRegistered: CharacterVersionRegistered,
        ScenarioRegistered: ScenarioMetadata,
        SimulationRegistered: SimulationRegistered,
        SessionRegistered: SessionMetadata,
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
    pub struct SimulationRegistered {
        #[key]
        pub simulation_id: felt252,
        pub simulation_hash: felt252,
        pub author: ContractAddress,
        pub character_id: felt252,
        pub scenario_id: felt252,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        paused: bool,
        nft_address: ContractAddress,
        /// Maps character version ID to its hash
        character_versions: Map<felt252, felt252>,
        // Character metadata:
        character_authors: Map<felt252, ContractAddress>,        // character_version_id -> author
        /// Maps scenario ID to its hash
        scenarios: Map<felt252, felt252>,
        // Scenario metadata:
        scenario_authors: Map<felt252, ContractAddress>,         // scenario_id -> author
        /// Maps simulation ID to its hash
        simulations: Map<felt252, felt252>,
        // Simulations metadata:
        simulation_authors: Map<felt252, ContractAddress>,        // simulation_id -> author
        simulation_characters: Map<felt252, felt252>,            // simulation_id -> character_id
        simulation_scenarios: Map<felt252, felt252>,             // simulation_id -> scenario_id
        // Sessions:
        session_roots: Map<felt252, felt252>,                     // session_id -> root_hash
        session_simulations: Map<felt252, felt252>,              // session_id -> simulation_id
        session_authors: Map<felt252, ContractAddress>,          // session_id -> author (seller original)
        session_scores: Map<felt252, u32>,                       // session_id -> score
        session_access: Map<(felt252, ContractAddress), bool>,   // (session_id, addr) -> true
    }

    pub mod Errors {
        pub const NFT_ADDRESS_CANNOT_BE_ZERO: felt252 = 'NFT address cannot be zero';
        pub const AUTHOR_MUST_OWN_NFT: felt252 = 'Author must own a Kliver NFT';
        pub const SESSION_ID_CANNOT_BE_ZERO: felt252 = 'Session ID cannot be zero';
        pub const ROOT_HASH_CANNOT_BE_ZERO: felt252 = 'Root hash cannot be zero';
        pub const AUTHOR_CANNOT_BE_ZERO: felt252 = 'Author cannot be zero';
        pub const SIMULATION_ID_CANNOT_BE_ZERO: felt252 = 'Simulation ID cannot be zero';
        pub const SIMULATION_NOT_FOUND: felt252 = 'Simulation not found';
        pub const CHARACTER_NOT_FOUND: felt252 = 'Character not found';
        pub const SCENARIO_NOT_FOUND: felt252 = 'Scenario not found';
        pub const SESSION_ALREADY_REGISTERED: felt252 = 'Session already registered';
        pub const SESSION_NOT_FOUND: felt252 = 'Session not found';
        pub const GRANTEE_CANNOT_BE_ZERO: felt252 = 'Grantee cannot be zero';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        nft_address: ContractAddress,
    ) {
        assert(!owner.is_zero(), 'Owner cannot be zero');
        assert(!nft_address.is_zero(), Errors::NFT_ADDRESS_CANNOT_BE_ZERO);
        self.owner.write(owner);
        self.nft_address.write(nft_address);
        self.paused.write(false);
    }

    // Character Registry Implementation
    #[abi(embed_v0)]
    impl CharacterRegistryImpl of ICharacterRegistry<ContractState> {
        fn register_character_version(ref self: ContractState, metadata: CharacterMetadata) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register character versions
            self._assert_only_owner();

            // Extract values from metadata
            let character_version_id = metadata.character_version_id;
            let character_version_hash = metadata.character_version_hash;
            let author = metadata.author;

            // Validate inputs
            assert(character_version_id != 0, 'Version ID cannot be zero');
            assert(character_version_hash != 0, 'Version hash cannot be zero');
            assert(!author.is_zero(), 'Author cannot be zero');

            // Validate that author has a Kliver NFT
            self._assert_author_has_nft(author);

            // Check if character version ID is already registered
            let existing_hash = self.character_versions.read(character_version_id);
            assert(existing_hash == 0, 'Version ID already registered');

            // Save the character version and metadata
            self.character_versions.write(character_version_id, character_version_hash);
            self.character_authors.write(character_version_id, author);

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

        fn batch_verify_character_versions(self: @ContractState, character_versions: Array<CharacterMetadata>) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = character_versions.len();

            while i != len {
                let metadata = *character_versions.at(i);
                let character_version_id = metadata.character_version_id;
                let character_version_hash = metadata.character_version_hash;

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

        fn get_character_version_info(self: @ContractState, character_version_id: felt252) -> CharacterMetadata {
            // Validate input
            assert(character_version_id != 0, 'Version ID cannot be zero');

            // Get the stored data for this character version ID
            let character_version_hash = self.character_versions.read(character_version_id);
            assert(character_version_hash != 0, 'Character version not found');

            let author = self.character_authors.read(character_version_id);

            // Return the complete metadata
            CharacterMetadata {
                character_version_id,
                character_version_hash,
                author,
            }
        }
    }

    // Scenario Registry Implementation
    #[abi(embed_v0)]
    impl ScenarioRegistryImpl of IScenarioRegistry<ContractState> {
        fn register_scenario(ref self: ContractState, metadata: ScenarioMetadata) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register scenarios
            self._assert_only_owner();

            // Extract values from metadata
            let scenario_id = metadata.scenario_id;
            let scenario_hash = metadata.scenario_hash;
            let author = metadata.author;

            // Validate inputs
            assert(scenario_id != 0, 'Scenario ID cannot be zero');
            assert(scenario_hash != 0, 'Scenario hash cannot be zero');
            assert(!author.is_zero(), 'Author cannot be zero');

            // Validate that author has a Kliver NFT
            self._assert_author_has_nft(author);

            // Check if scenario is already registered
            let existing_hash = self.scenarios.read(scenario_id);
            assert(existing_hash == 0, 'Scenario already registered');

            // Save the scenario and metadata
            self.scenarios.write(scenario_id, scenario_hash);
            self.scenario_authors.write(scenario_id, author);

            // Emit event
            self.emit(Event::ScenarioRegistered(metadata));
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

        fn batch_verify_scenarios(self: @ContractState, scenarios: Array<ScenarioMetadata>) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = scenarios.len();

            while i != len {
                let metadata = *scenarios.at(i);
                let scenario_id = metadata.scenario_id;
                let scenario_hash = metadata.scenario_hash;

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

        fn get_scenario_info(self: @ContractState, scenario_id: felt252) -> ScenarioMetadata {
            // Validate input
            assert(scenario_id != 0, 'Scenario ID cannot be zero');

            // Get the stored data for this scenario ID
            let scenario_hash = self.scenarios.read(scenario_id);
            assert(scenario_hash != 0, 'Scenario not found');

            let author = self.scenario_authors.read(scenario_id);

            // Return the complete metadata
            ScenarioMetadata {
                scenario_id,
                scenario_hash,
                author,
            }
        }
    }

    // Simulation Registry Implementation
    #[abi(embed_v0)]
    impl SimulationRegistryImpl of ISimulationRegistry<ContractState> {
        fn register_simulation(ref self: ContractState, metadata: SimulationMetadata) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register simulations
            self._assert_only_owner();

            // Validate inputs
            assert(metadata.simulation_id != 0, 'Simulation ID cannot be zero');
            assert(metadata.simulation_hash != 0, 'Simulation hash cannot be zero');
            assert(!metadata.author.is_zero(), 'Author cannot be zero');
            assert(metadata.character_id != 0, 'Character ID cannot be zero');
            assert(metadata.scenario_id != 0, 'Scenario ID cannot be zero');

            // Validate that author has a Kliver NFT
            self._assert_author_has_nft(metadata.author);

            // Validate that character exists
            let character_hash = self.character_versions.read(metadata.character_id);
            assert(character_hash != 0, Errors::CHARACTER_NOT_FOUND);

            // Validate that scenario exists
            let scenario_hash = self.scenarios.read(metadata.scenario_id);
            assert(scenario_hash != 0, Errors::SCENARIO_NOT_FOUND);

            // Check if simulation is already registered
            let existing_hash = self.simulations.read(metadata.simulation_id);
            assert(existing_hash == 0, 'Simulation already registered');

            // Save the simulation and metadata
            self.simulations.write(metadata.simulation_id, metadata.simulation_hash);
            self.simulation_authors.write(metadata.simulation_id, metadata.author);
            self.simulation_characters.write(metadata.simulation_id, metadata.character_id);
            self.simulation_scenarios.write(metadata.simulation_id, metadata.scenario_id);

            // Emit event
            self.emit(SimulationRegistered {
                simulation_id: metadata.simulation_id,
                simulation_hash: metadata.simulation_hash,
                author: metadata.author,
                character_id: metadata.character_id,
                scenario_id: metadata.scenario_id,
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

        fn batch_verify_simulations(self: @ContractState, simulations: Array<SimulationMetadata>) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = simulations.len();

            while i != len {
                let metadata = *simulations.at(i);
                let simulation_id = metadata.simulation_id;
                let simulation_hash = metadata.simulation_hash;

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

        fn get_simulation_info(self: @ContractState, simulation_id: felt252) -> SimulationMetadata {
            // Validate input
            assert(simulation_id != 0, 'Simulation ID cannot be zero');

            // Get the stored data for this simulation ID
            let simulation_hash = self.simulations.read(simulation_id);
            assert(simulation_hash != 0, 'Simulation not found');

            let author = self.simulation_authors.read(simulation_id);
            let character_id = self.simulation_characters.read(simulation_id);
            let scenario_id = self.simulation_scenarios.read(simulation_id);

            SimulationMetadata {
                simulation_id,
                author,
                character_id,
                scenario_id,
                simulation_hash,
            }
        }
    }

    // Session Registry Implementation
    #[abi(embed_v0)]
    impl SessionRegistryImpl of ISessionRegistry<ContractState> {
        fn register_session(ref self: ContractState, metadata: SessionMetadata) {
            self._assert_not_paused();
            self._assert_only_owner(); // Por ahora, sólo Kliver registra

            assert(metadata.session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            assert(metadata.root_hash != 0, Errors::ROOT_HASH_CANNOT_BE_ZERO);
            assert(metadata.simulation_id != 0, Errors::SIMULATION_ID_CANNOT_BE_ZERO);
            assert(!metadata.author.is_zero(), Errors::AUTHOR_CANNOT_BE_ZERO);

            // Validate that the simulation exists
            let simulation_hash = self.simulations.read(metadata.simulation_id);
            assert(simulation_hash != 0, Errors::SIMULATION_NOT_FOUND);

            let existing = self.session_roots.read(metadata.session_id);
            assert(existing == 0, Errors::SESSION_ALREADY_REGISTERED);

            self.session_roots.write(metadata.session_id, metadata.root_hash);
            self.session_simulations.write(metadata.session_id, metadata.simulation_id);
            self.session_authors.write(metadata.session_id, metadata.author);
            self.session_scores.write(metadata.session_id, metadata.score);

            self.emit(Event::SessionRegistered(metadata));
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

        fn get_session_info(self: @ContractState, session_id: felt252) -> SessionMetadata {
            assert(session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            let root_hash = self.session_roots.read(session_id);
            assert(root_hash != 0, Errors::SESSION_NOT_FOUND);
            let simulation_id = self.session_simulations.read(session_id);
            let author = self.session_authors.read(session_id);
            let score = self.session_scores.read(session_id);
            
            SessionMetadata {
                session_id,
                root_hash,
                simulation_id,
                author,
                score
            }
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

        fn get_nft_address(self: @ContractState) -> ContractAddress {
            self.nft_address.read()
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

        fn _assert_author_has_nft(self: @ContractState, author: ContractAddress) {
            let nft_address = self.nft_address.read();
            let nft_dispatcher = IKliverNFTDispatcher { contract_address: nft_address };
            let has_nft = nft_dispatcher.user_has_nft(author);
            assert(has_nft, Errors::AUTHOR_MUST_OWN_NFT);
        }
    }
}