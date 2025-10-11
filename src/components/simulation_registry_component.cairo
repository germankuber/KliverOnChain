use starknet::ContractAddress;

#[derive(Drop, Serde, Copy)]
pub struct SimulationMetadata {
    pub simulation_id: felt252,
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
    pub simulation_hash: felt252,
}

#[derive(Drop, Serde, Copy)]
pub struct SimulationWithTokenMetadata {
    pub simulation_id: felt252,
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
    pub simulation_hash: felt252,
    pub token_id: u256,
    pub expiration_timestamp: u64,
}

#[starknet::component]
pub mod SimulationRegistryComponent {
    use kliver_on_chain::types::VerificationResult;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::{SimulationMetadata, SimulationWithTokenMetadata};

    #[storage]
    pub struct Storage {
        /// Maps simulation ID to its hash
        pub simulations: Map<felt252, felt252>,
        /// Simulation metadata
        pub simulation_authors: Map<felt252, ContractAddress>,
        pub simulation_characters: Map<felt252, felt252>,
        pub simulation_scenarios: Map<felt252, felt252>,
        pub simulation_token_ids: Map<felt252, u256>,
        pub simulation_expirations: Map<felt252, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SimulationRegistered: SimulationRegistered,
        SimulationWithTokenRegistered: SimulationWithTokenRegistered,
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

    #[derive(Drop, starknet::Event)]
    pub struct SimulationWithTokenRegistered {
        #[key]
        pub simulation_id: felt252,
        pub simulation_hash: felt252,
        pub author: ContractAddress,
        pub character_id: felt252,
        pub scenario_id: felt252,
        pub token_id: u256,
        pub expiration_timestamp: u64,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Register a simulation without token
        fn register_simulation(
            ref self: ComponentState<TContractState>,
            simulation_id: felt252,
            simulation_hash: felt252,
            author: ContractAddress,
            character_id: felt252,
            scenario_id: felt252,
        ) {
            // Store simulation data
            self.simulations.entry(simulation_id).write(simulation_hash);
            self.simulation_authors.entry(simulation_id).write(author);
            self.simulation_characters.entry(simulation_id).write(character_id);
            self.simulation_scenarios.entry(simulation_id).write(scenario_id);

            // Emit event
            self
                .emit(
                    SimulationRegistered {
                        simulation_id, simulation_hash, author, character_id, scenario_id,
                    },
                );
        }

        /// Register a simulation with token
        fn register_simulation_with_token(
            ref self: ComponentState<TContractState>,
            simulation_id: felt252,
            simulation_hash: felt252,
            author: ContractAddress,
            character_id: felt252,
            scenario_id: felt252,
            token_id: u256,
            expiration_timestamp: u64,
        ) {
            // Store simulation data
            self.simulations.entry(simulation_id).write(simulation_hash);
            self.simulation_authors.entry(simulation_id).write(author);
            self.simulation_characters.entry(simulation_id).write(character_id);
            self.simulation_scenarios.entry(simulation_id).write(scenario_id);
            self.simulation_token_ids.entry(simulation_id).write(token_id);
            self.simulation_expirations.entry(simulation_id).write(expiration_timestamp);

            // Emit event
            self
                .emit(
                    SimulationWithTokenRegistered {
                        simulation_id,
                        simulation_hash,
                        author,
                        character_id,
                        scenario_id,
                        token_id,
                        expiration_timestamp,
                    },
                );
        }

        /// Verify if a simulation ID matches its expected hash
        fn verify_simulation(
            self: @ComponentState<TContractState>, simulation_id: felt252, simulation_hash: felt252,
        ) -> VerificationResult {
            let stored_hash = self.simulations.entry(simulation_id).read();

            if stored_hash == 0 {
                VerificationResult::NotFound
            } else if stored_hash == simulation_hash {
                VerificationResult::Match
            } else {
                VerificationResult::Mismatch
            }
        }

        /// Verify multiple simulations at once
        fn batch_verify_simulations(
            self: @ComponentState<TContractState>, simulations: Array<SimulationMetadata>,
        ) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = simulations.len();

            while i != len {
                let metadata = *simulations.at(i);
                let simulation_id = metadata.simulation_id;
                let simulation_hash = metadata.simulation_hash;

                let verification_result = if simulation_id == 0 || simulation_hash == 0 {
                    VerificationResult::NotFound
                } else {
                    let stored_hash = self.simulations.entry(simulation_id).read();

                    if stored_hash == 0 {
                        VerificationResult::NotFound
                    } else if stored_hash == simulation_hash {
                        VerificationResult::Match
                    } else {
                        VerificationResult::Mismatch
                    }
                };

                results.append((simulation_id, verification_result));
                i += 1;
            }

            results
        }

        /// Get the hash for a simulation ID
        fn get_simulation_hash(
            self: @ComponentState<TContractState>, simulation_id: felt252,
        ) -> felt252 {
            let hash = self.simulations.entry(simulation_id).read();
            assert(hash != 0, 'Simulation not found');
            hash
        }

        /// Get complete simulation information
        fn get_simulation_info(
            self: @ComponentState<TContractState>, simulation_id: felt252,
        ) -> SimulationMetadata {
            let simulation_hash = self.simulations.entry(simulation_id).read();
            assert(simulation_hash != 0, 'Simulation not found');
            let author = self.simulation_authors.entry(simulation_id).read();
            let character_id = self.simulation_characters.entry(simulation_id).read();
            let scenario_id = self.simulation_scenarios.entry(simulation_id).read();

            SimulationMetadata { simulation_id, author, character_id, scenario_id, simulation_hash }
        }

        /// Get complete simulation information including token data
        fn get_simulation_with_token_info(
            self: @ComponentState<TContractState>, simulation_id: felt252,
        ) -> SimulationWithTokenMetadata {
            let simulation_hash = self.simulations.entry(simulation_id).read();
            assert(simulation_hash != 0, 'Simulation not found');
            let author = self.simulation_authors.entry(simulation_id).read();
            let character_id = self.simulation_characters.entry(simulation_id).read();
            let scenario_id = self.simulation_scenarios.entry(simulation_id).read();
            let token_id = self.simulation_token_ids.entry(simulation_id).read();
            let expiration_timestamp = self.simulation_expirations.entry(simulation_id).read();

            SimulationWithTokenMetadata {
                simulation_id,
                author,
                character_id,
                scenario_id,
                simulation_hash,
                token_id,
                expiration_timestamp,
            }
        }

        /// Check if a simulation exists
        fn simulation_exists(
            self: @ComponentState<TContractState>, simulation_id: felt252,
        ) -> bool {
            self.simulations.entry(simulation_id).read() != 0
        }
    }
}
