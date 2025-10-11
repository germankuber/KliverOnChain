use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, starknet::Event)]
pub struct ScenarioMetadata {
    #[key]
    pub scenario_id: felt252,
    pub scenario_hash: felt252,
    pub author: ContractAddress,
}

#[starknet::component]
pub mod ScenarioRegistryComponent {
    use kliver_on_chain::types::VerificationResult;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::ScenarioMetadata;

    #[storage]
    pub struct Storage {
        /// Maps scenario ID to its hash
        pub scenarios: Map<felt252, felt252>,
        /// Maps scenario ID to its author
        pub scenario_authors: Map<felt252, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ScenarioRegistered: ScenarioMetadata,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Register a scenario with its ID, hash and author
        fn register_scenario(
            ref self: ComponentState<TContractState>,
            scenario_id: felt252,
            scenario_hash: felt252,
            author: ContractAddress,
        ) {
            // Store scenario hash and author
            self.scenarios.entry(scenario_id).write(scenario_hash);
            self.scenario_authors.entry(scenario_id).write(author);

            // Emit event
            self.emit(ScenarioMetadata { scenario_id, scenario_hash, author });
        }

        /// Verify if a scenario ID matches its expected hash
        fn verify_scenario(
            self: @ComponentState<TContractState>, scenario_id: felt252, scenario_hash: felt252,
        ) -> VerificationResult {
            let stored_hash = self.scenarios.entry(scenario_id).read();

            if stored_hash == 0 {
                VerificationResult::NotFound
            } else if stored_hash == scenario_hash {
                VerificationResult::Match
            } else {
                VerificationResult::Mismatch
            }
        }

        /// Verify multiple scenarios at once
        fn batch_verify_scenarios(
            self: @ComponentState<TContractState>, scenarios: Array<ScenarioMetadata>,
        ) -> Array<(felt252, VerificationResult)> {
            let mut results: Array<(felt252, VerificationResult)> = ArrayTrait::new();
            let mut i = 0;
            let len = scenarios.len();

            while i != len {
                let metadata = *scenarios.at(i);
                let scenario_id = metadata.scenario_id;
                let scenario_hash = metadata.scenario_hash;

                let verification_result = if scenario_id == 0 || scenario_hash == 0 {
                    VerificationResult::NotFound
                } else {
                    let stored_hash = self.scenarios.entry(scenario_id).read();

                    if stored_hash == 0 {
                        VerificationResult::NotFound
                    } else if stored_hash == scenario_hash {
                        VerificationResult::Match
                    } else {
                        VerificationResult::Mismatch
                    }
                };

                results.append((scenario_id, verification_result));
                i += 1;
            }

            results
        }

        /// Get the hash for a scenario ID
        fn get_scenario_hash(
            self: @ComponentState<TContractState>, scenario_id: felt252,
        ) -> felt252 {
            let hash = self.scenarios.entry(scenario_id).read();
            assert(hash != 0, 'Scenario not found');
            hash
        }

        /// Get complete scenario information
        fn get_scenario_info(
            self: @ComponentState<TContractState>, scenario_id: felt252,
        ) -> ScenarioMetadata {
            let scenario_hash = self.scenarios.entry(scenario_id).read();
            assert(scenario_hash != 0, 'Scenario not found');
            let author = self.scenario_authors.entry(scenario_id).read();

            ScenarioMetadata { scenario_id, scenario_hash, author }
        }

        /// Check if a scenario exists
        fn scenario_exists(self: @ComponentState<TContractState>, scenario_id: felt252) -> bool {
            self.scenarios.entry(scenario_id).read() != 0
        }
    }
}
