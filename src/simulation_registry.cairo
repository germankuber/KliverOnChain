use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Simulation metadata for registration
#[derive(Drop, Serde, Copy)]
pub struct SimulationMetadata {
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
}

/// Information returned when querying a simulation
#[derive(Drop, Serde)]
pub struct SimulationInfo {
    pub simulation_hash: felt252,
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
}

/// Simulation Registry Interface
#[starknet::interface]
pub trait ISimulationRegistry<TContractState> {
    /// Register a simulation with its metadata (only owner)
    fn register_simulation(ref self: TContractState, simulation_id: felt252, simulation_hash: felt252, metadata: SimulationMetadata);
    /// Verify if a simulation ID matches its expected hash
    fn verify_simulation(self: @TContractState, simulation_id: felt252, simulation_hash: felt252) -> VerificationResult;
    /// Verify multiple simulations at once
    fn batch_verify_simulations(self: @TContractState, simulations: Array<(felt252, felt252)>) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a simulation ID
    fn get_simulation_hash(self: @TContractState, simulation_id: felt252) -> felt252;
    /// Get complete simulation information
    fn get_simulation_info(self: @TContractState, simulation_id: felt252) -> SimulationInfo;
}

/// Simulation Registered Event
#[derive(Drop, starknet::Event)]
pub struct SimulationRegistered {
    #[key]
    pub simulation_id: felt252,
    pub simulation_hash: felt252,
    pub author: ContractAddress,
    pub character_id: felt252,
    pub scenario_id: felt252,
}