// Import interfaces from separate modules
use crate::character_registry::ICharacterRegistry;
use crate::owner_registry::IOwnerRegistry;
use crate::scenario_registry::IScenarioRegistry;
use crate::session_registry::ISessionRegistry;
use crate::simulation_registry::ISimulationRegistry;
use crate::types::VerificationResult;

/// Verifier Interface for proof verification
#[starknet::interface]
pub trait IVerifier<TContractState> {
    fn verify_ultra_starknet_honk_proof(
        self: @TContractState, full_proof_with_hints: Span<felt252>,
    ) -> Option<Span<u256>>;
}

/// Token Core Interface for simulation registration
#[starknet::interface]
pub trait ITokenCore<TContractState> {
    fn register_simulation(
        ref self: TContractState, simulation_id: felt252, token_id: u256, expiration_timestamp: u64,
    ) -> felt252;
}

/// Kliver Registry Contract
//

#[starknet::contract]
pub mod kliver_registry {
    use core::num::traits::Zero;
    use kliver_on_chain::components::character_registry_component::{
        CharacterMetadata, CharacterRegistryComponent,
    };
    use kliver_on_chain::components::scenario_registry_component::{
        ScenarioMetadata, ScenarioRegistryComponent,
    };
    use kliver_on_chain::components::session_registry_component::{
        SessionMetadata, SessionRegistryComponent,
    };
    use kliver_on_chain::components::simulation_registry_component::{
        SimulationMetadata, SimulationRegistryComponent, SimulationWithTokenMetadata,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use crate::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};
    use super::{
        ICharacterRegistry, IOwnerRegistry, IScenarioRegistry, ISessionRegistry,
        ISimulationRegistry, ITokenCoreDispatcher, ITokenCoreDispatcherTrait, IVerifierDispatcher,
        IVerifierDispatcherTrait, VerificationResult,
    };

    component!(
        path: CharacterRegistryComponent,
        storage: character_registry,
        event: CharacterRegistryEvent,
    );
    component!(
        path: ScenarioRegistryComponent, storage: scenario_registry, event: ScenarioRegistryEvent,
    );
    component!(
        path: SimulationRegistryComponent,
        storage: simulation_registry,
        event: SimulationRegistryEvent,
    );
    component!(
        path: SessionRegistryComponent, storage: session_registry, event: SessionRegistryEvent,
    );

    impl CharacterRegistryInternalImpl = CharacterRegistryComponent::InternalImpl<ContractState>;
    impl ScenarioRegistryInternalImpl = ScenarioRegistryComponent::InternalImpl<ContractState>;
    impl SimulationRegistryInternalImpl = SimulationRegistryComponent::InternalImpl<ContractState>;
    impl SessionRegistryInternalImpl = SessionRegistryComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        CharacterRegistryEvent: CharacterRegistryComponent::Event,
        #[flat]
        ScenarioRegistryEvent: ScenarioRegistryComponent::Event,
        #[flat]
        SimulationRegistryEvent: SimulationRegistryComponent::Event,
        #[flat]
        SessionRegistryEvent: SessionRegistryComponent::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        character_registry: CharacterRegistryComponent::Storage,
        #[substorage(v0)]
        scenario_registry: ScenarioRegistryComponent::Storage,
        #[substorage(v0)]
        simulation_registry: SimulationRegistryComponent::Storage,
        #[substorage(v0)]
        session_registry: SessionRegistryComponent::Storage,
        owner: ContractAddress,
        paused: bool,
        nft_address: ContractAddress,
        tokens_core_address: ContractAddress,
        verifier_address: ContractAddress,
    }

    pub mod Errors {
        pub const NFT_ADDRESS_CANNOT_BE_ZERO: felt252 = 'NFT address cannot be zero';
        pub const TOKENS_CORE_ADDRESS_CANNOT_BE_ZERO: felt252 = 'Tokens core addr cannot be zero';
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
        tokens_core_address: ContractAddress,
        verifier_address: ContractAddress,
    ) {
        assert(!owner.is_zero(), 'Owner cannot be zero');
        assert(!nft_address.is_zero(), Errors::NFT_ADDRESS_CANNOT_BE_ZERO);
        assert(!tokens_core_address.is_zero(), Errors::TOKENS_CORE_ADDRESS_CANNOT_BE_ZERO);
        assert(!verifier_address.is_zero(), 'Verifier address cannot be zero');
        self.owner.write(owner);
        self.nft_address.write(nft_address);
        self.tokens_core_address.write(tokens_core_address);
        self.verifier_address.write(verifier_address);
        self.paused.write(false);
    }

    // Character Registry Implementation
    #[abi(embed_v0)]
    impl CharacterRegistryImpl of ICharacterRegistry<ContractState> {
        fn register_character(ref self: ContractState, metadata: CharacterMetadata) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register characters
            self._assert_only_owner();

            // Extract values from metadata
            let character_id = metadata.character_id;
            let character_hash = metadata.character_hash;
            let author = metadata.author;

            // Validate inputs (business logic)
            assert(character_id != 0, 'Character ID cannot be zero');
            assert(character_hash != 0, 'Character hash cannot be zero');
            assert(!author.is_zero(), 'Author cannot be zero');

            // Validate that author has a Kliver NFT
            self._assert_author_has_nft(author);

            // Check if character ID is already registered
            assert(
                !self.character_registry.character_exists(character_id),
                'Character ID already registered',
            );

            // Register using component
            self
                .character_registry
                .register_character(character_id, character_hash, author, get_caller_address());
        }

        fn verify_character(
            self: @ContractState, character_id: felt252, character_hash: felt252,
        ) -> VerificationResult {
            // Validate inputs (business logic)
            assert(character_id != 0, 'Character ID cannot be zero');
            assert(character_hash != 0, 'Character hash cannot be zero');

            // Use component for verification
            self.character_registry.verify_character(character_id, character_hash)
        }

        fn batch_verify_characters(
            self: @ContractState, characters: Array<CharacterMetadata>,
        ) -> Array<(felt252, VerificationResult)> {
            // Use component for batch verification
            self.character_registry.batch_verify_characters(characters)
        }

        fn get_character_hash(self: @ContractState, character_id: felt252) -> felt252 {
            // Validate input (business logic)
            assert(character_id != 0, 'Character ID cannot be zero');

            // Get hash from component
            let stored_hash = self.character_registry.get_character_hash(character_id);

            // Validate that character exists
            assert(stored_hash != 0, 'Character not found');

            stored_hash
        }

        fn get_character_info(self: @ContractState, character_id: felt252) -> CharacterMetadata {
            // Validate input (business logic)
            assert(character_id != 0, 'Character ID cannot be zero');

            // Get info from component
            let info = self.character_registry.get_character_info(character_id);

            // Validate that character exists
            assert(info.character_hash != 0, 'Character not found');

            info
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

            // Check if scenario already exists
            assert(
                !self.scenario_registry.scenario_exists(scenario_id), 'Scenario already registered',
            );

            // Delegate to component
            self.scenario_registry.register_scenario(scenario_id, scenario_hash, author);
        }

        fn verify_scenario(
            self: @ContractState, scenario_id: felt252, scenario_hash: felt252,
        ) -> VerificationResult {
            // Delegate to component
            self.scenario_registry.verify_scenario(scenario_id, scenario_hash)
        }

        fn batch_verify_scenarios(
            self: @ContractState, scenarios: Array<ScenarioMetadata>,
        ) -> Array<(felt252, VerificationResult)> {
            // Delegate to component
            self.scenario_registry.batch_verify_scenarios(scenarios)
        }

        fn get_scenario_hash(self: @ContractState, scenario_id: felt252) -> felt252 {
            // Delegate to component
            self.scenario_registry.get_scenario_hash(scenario_id)
        }

        fn get_scenario_info(self: @ContractState, scenario_id: felt252) -> ScenarioMetadata {
            // Delegate to component
            self.scenario_registry.get_scenario_info(scenario_id)
        }
    }

    // Simulation Registry Implementation
    #[abi(embed_v0)]
    impl SimulationRegistryImpl of ISimulationRegistry<ContractState> {
        fn register_simulation(ref self: ContractState, metadata: SimulationMetadata) {
            self
                ._register_simulation_internal(
                    metadata.simulation_id,
                    metadata.simulation_hash,
                    metadata.author,
                    metadata.character_id,
                    metadata.scenario_id,
                );
        }

        fn register_simulation_with_token(
            ref self: ContractState, metadata: SimulationWithTokenMetadata,
        ) {
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
            assert(metadata.token_id != 0, 'Token ID cannot be zero');
            assert(metadata.expiration_timestamp > 0, 'Expiration must be > 0');

            // Validate that author has a Kliver NFT
            self._assert_author_has_nft(metadata.author);

            // Validate that character exists using component
            assert(
                self.character_registry.character_exists(metadata.character_id),
                Errors::CHARACTER_NOT_FOUND,
            );

            // Validate that scenario exists using component
            assert(
                self.scenario_registry.scenario_exists(metadata.scenario_id),
                Errors::SCENARIO_NOT_FOUND,
            );

            // Delegate to component
            self
                .simulation_registry
                .register_simulation_with_token(
                    metadata.simulation_id,
                    metadata.simulation_hash,
                    metadata.author,
                    metadata.character_id,
                    metadata.scenario_id,
                    metadata.token_id,
                    metadata.expiration_timestamp,
                );

            // Call token core to register the simulation
            let token_core_address = self.tokens_core_address.read();
            let token_core_dispatcher = ITokenCoreDispatcher {
                contract_address: token_core_address,
            };
            token_core_dispatcher
                .register_simulation(
                    metadata.simulation_id, metadata.token_id, metadata.expiration_timestamp,
                );
            // Event is emitted from component
        }

        fn verify_simulation(
            self: @ContractState, simulation_id: felt252, simulation_hash: felt252,
        ) -> VerificationResult {
            // Delegate to component
            self.simulation_registry.verify_simulation(simulation_id, simulation_hash)
        }

        fn batch_verify_simulations(
            self: @ContractState, simulations: Array<SimulationMetadata>,
        ) -> Array<(felt252, VerificationResult)> {
            // Delegate to component
            self.simulation_registry.batch_verify_simulations(simulations)
        }

        fn get_simulation_hash(self: @ContractState, simulation_id: felt252) -> felt252 {
            // Delegate to component
            self.simulation_registry.get_simulation_hash(simulation_id)
        }

        fn get_simulation_info(self: @ContractState, simulation_id: felt252) -> SimulationMetadata {
            // Delegate to component
            self.simulation_registry.get_simulation_info(simulation_id)
        }

        fn get_simulation_with_token_info(
            self: @ContractState, simulation_id: felt252,
        ) -> SimulationWithTokenMetadata {
            // Delegate to component
            self.simulation_registry.get_simulation_with_token_info(simulation_id)
        }

        fn simulation_exists(self: @ContractState, simulation_id: felt252) -> bool {
            // Delegate to component
            self.simulation_registry.simulation_exists(simulation_id)
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

            // Validate that the author has an NFT
            self._assert_author_has_nft(metadata.author);

            // Validate that the simulation exists using component
            assert(
                self.simulation_registry.simulation_exists(metadata.simulation_id),
                Errors::SIMULATION_NOT_FOUND,
            );

            // Check if session already exists
            assert(
                !self.session_registry.session_exists(metadata.session_id),
                Errors::SESSION_ALREADY_REGISTERED,
            );

            // Delegate to component
            self
                .session_registry
                .register_session(
                    metadata.session_id,
                    metadata.root_hash,
                    metadata.simulation_id,
                    metadata.author,
                    metadata.score,
                );
        }

        fn verify_session(
            self: @ContractState, session_id: felt252, root_hash: felt252,
        ) -> VerificationResult {
            // Delegate to component
            self.session_registry.verify_session(session_id, root_hash)
        }

        fn verify_complete_session(
            self: @ContractState, full_proof_with_hints: Span<felt252>,
        ) -> Option<Span<u256>> {
            let verifier = IVerifierDispatcher { contract_address: self.verifier_address.read() };
            verifier.verify_ultra_starknet_honk_proof(full_proof_with_hints)
        }

        fn verify_proof(
            self: @ContractState, full_proof_with_hints: Span<felt252>, root_hash: felt252, challenge: u64
        ) -> Option<Span<u256>> {
            // Validate 10-digit numeric key
            assert(challenge >= 1000000000_u64, 'Invalid challenge');
            assert(challenge <= 9999999999_u64, 'Invalid challenge');
            let verifier = IVerifierDispatcher { contract_address: self.verifier_address.read() };
            let result = verifier.verify_ultra_starknet_honk_proof(full_proof_with_hints);
            result
        }

        fn get_session_info(self: @ContractState, session_id: felt252) -> SessionMetadata {
            // Delegate to component
            self.session_registry.get_session_info(session_id)
        }

        // ---- Opcional: access list (trazabilidad de ventas) ----
        fn grant_access(ref self: ContractState, session_id: felt252, addr: ContractAddress) {
            self._assert_not_paused();
            self
                ._assert_only_owner(); // o permitir también al author si querés: assert(get_caller==owner || == author)

            assert(session_id != 0, Errors::SESSION_ID_CANNOT_BE_ZERO);
            assert(!addr.is_zero(), Errors::GRANTEE_CANNOT_BE_ZERO);

            // Verify session exists using component
            assert(self.session_registry.session_exists(session_id), Errors::SESSION_NOT_FOUND);

            // Delegate to component
            let caller = get_caller_address();
            self.session_registry.grant_access(session_id, addr, caller);
        }

        fn has_access(self: @ContractState, session_id: felt252, addr: ContractAddress) -> bool {
            // Delegate to component
            self.session_registry.has_access(session_id, addr)
        }

        fn get_verifier_address(self: @ContractState) -> ContractAddress {
            self.verifier_address.read()
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

        fn get_tokens_core_address(self: @ContractState) -> ContractAddress {
            self.tokens_core_address.read()
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

        fn _register_simulation_internal(
            ref self: ContractState,
            simulation_id: felt252,
            simulation_hash: felt252,
            author: ContractAddress,
            character_id: felt252,
            scenario_id: felt252,
        ) {
            // Check if contract is paused
            self._assert_not_paused();
            // Only owner can register simulations
            self._assert_only_owner();

            // Validate inputs
            assert(simulation_id != 0, 'Simulation ID cannot be zero');
            assert(simulation_hash != 0, 'Simulation hash cannot be zero');
            assert(!author.is_zero(), 'Author cannot be zero');
            assert(character_id != 0, 'Character ID cannot be zero');
            assert(scenario_id != 0, 'Scenario ID cannot be zero');

            // Validate that author has a Kliver NFT
            self._assert_author_has_nft(author);

            // Validate that character exists using component
            assert(
                self.character_registry.character_exists(character_id), Errors::CHARACTER_NOT_FOUND,
            );

            // Validate that scenario exists using component
            assert(self.scenario_registry.scenario_exists(scenario_id), Errors::SCENARIO_NOT_FOUND);

            // Delegate to component
            self
                .simulation_registry
                .register_simulation(
                    simulation_id, simulation_hash, author, character_id, scenario_id,
                );
        }
    }
}
