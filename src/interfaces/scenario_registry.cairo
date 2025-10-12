pub use kliver_on_chain::components::scenario_registry_component::ScenarioMetadata;
use crate::types::VerificationResult;

#[starknet::interface]
pub trait IScenarioRegistry<TContractState> {
    fn register_scenario(ref self: TContractState, metadata: ScenarioMetadata);
    fn verify_scenario(self: @TContractState, scenario_id: felt252, scenario_hash: felt252) -> VerificationResult;
    fn batch_verify_scenarios(self: @TContractState, scenarios: Array<ScenarioMetadata>) -> Array<(felt252, VerificationResult)>;
    fn get_scenario_hash(self: @TContractState, scenario_id: felt252) -> felt252;
    fn get_scenario_info(self: @TContractState, scenario_id: felt252) -> ScenarioMetadata;
}

