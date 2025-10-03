/// Common types used across the registry modules

/// Verification Result Enum
#[derive(Drop, Serde, PartialEq, Copy)]
pub enum VerificationResult {
    NotFound,  // ID does not exist in the registry
    Mismatch,  // ID exists but the hash does not match
    Match,     // ID exists and the hash matches
}