/// Common types used across the registry modules

/// Verification Result Enum
#[derive(Drop, Serde, PartialEq, Copy)]
pub enum VerificationResult {
    NotFound, // ID does not exist in the registry
    Mismatch, // ID exists but the hash does not match
    Match // ID exists and the hash matches
}

/// Struct for batch simulation verification request
#[derive(Drop, Serde, Copy)]
pub struct SimulationVerificationRequest {
    pub simulation_id: felt252,
    pub simulation_hash: felt252,
}

/// Struct for batch simulation verification result
#[derive(Drop, Serde, Copy)]
pub struct SimulationVerificationResult {
    pub simulation_id: felt252,
    pub result: VerificationResult,
}

/// Struct for batch scenario verification request
#[derive(Drop, Serde, Copy)]
pub struct ScenarioVerificationRequest {
    pub scenario_id: felt252,
    pub scenario_hash: felt252,
}

/// Struct for batch scenario verification result
#[derive(Drop, Serde, Copy)]
pub struct ScenarioVerificationResult {
    pub scenario_id: felt252,
    pub result: VerificationResult,
}
