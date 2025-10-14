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

/// Struct for batch character verification request
#[derive(Drop, Serde, Copy)]
pub struct CharacterVerificationRequest {
    pub character_id: felt252,
    pub character_hash: felt252,
}

/// Struct for batch character verification result
#[derive(Drop, Serde, Copy)]
pub struct CharacterVerificationResult {
    pub character_id: felt252,
    pub result: VerificationResult,
}

/// Struct for batch session verification request (by session_id)
#[derive(Drop, Serde, Copy)]
pub struct SessionVerificationRequest {
    pub session_id: felt252,
    pub root_hash: felt252,
}

/// Struct for batch session verification result
#[derive(Drop, Serde, Copy)]
pub struct SessionVerificationResult {
    pub session_id: felt252,
    pub result: VerificationResult,
}
