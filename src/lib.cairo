// Kliver Registry - Main Library Entry Point
// This modular structure separates concerns by registry type for better maintainability

// Common types module
pub mod types;

// Registry interface modules - separated by functionality
pub mod character_registry;
pub mod scenario_registry;
pub mod simulation_registry;
pub mod owner_registry;
pub mod session_registry;

// Main contract module
pub mod kliver_registry;

// NFT module
pub mod kliver_nft;

// Re-export key types for easier access
pub use types::VerificationResult;