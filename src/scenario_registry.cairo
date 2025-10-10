use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Scenario metadata for registration
#[derive(Drop, Serde, Copy, starknet::Event)]
pub struct ScenarioMetadata {
    #[key]
    pub scenario_id: felt252,
    pub scenario_hash: felt252,
    pub author: ContractAddress,
}

/// Scenario Registry Interface
#[starknet::interface]
pub trait IScenarioRegistry<TContractState> {
    /// Register a scenario with its metadata (only owner)
    fn register_scenario(ref self: TContractState, metadata: ScenarioMetadata);
    /// Verify if a scenario ID matches its expected hash
    fn verify_scenario(
        self: @TContractState, scenario_id: felt252, scenario_hash: felt252,
    ) -> VerificationResult;
    /// Verify multiple scenarios at once
    fn batch_verify_scenarios(
        self: @TContractState, scenarios: Array<ScenarioMetadata>,
    ) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a scenario ID
    fn get_scenario_hash(self: @TContractState, scenario_id: felt252) -> felt252;
    /// Get complete scenario information
    fn get_scenario_info(self: @TContractState, scenario_id: felt252) -> ScenarioMetadata;
}
