use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Scenario Registry Interface
#[starknet::interface]
pub trait IScenarioRegistry<TContractState> {
    /// Register a scenario with its ID and hash (only owner)
    fn register_scenario(ref self: TContractState, scenario_id: felt252, scenario_hash: felt252);
    /// Verify if a scenario ID matches its expected hash
    fn verify_scenario(self: @TContractState, scenario_id: felt252, scenario_hash: felt252) -> VerificationResult;
    /// Verify multiple scenarios at once
    fn batch_verify_scenarios(self: @TContractState, scenarios: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a scenario ID
    fn get_scenario_hash(self: @TContractState, scenario_id: felt252) -> felt252;
}

/// Scenario Registered Event
#[derive(Drop, starknet::Event)]
pub struct ScenarioRegistered {
    #[key]
    pub scenario_id: felt252,
    pub scenario_hash: felt252,
    pub registered_by: ContractAddress,
}