// Kliver Registry - Main Library Entry Point
// This modular structure separates concerns by registry type for better maintainability

// Common types module
pub mod types;

// Registry interface modules - separated by functionality
pub mod character_registry;
pub mod scenario_registry;
pub mod simulation_registry;
pub mod owner_registry;

// Main contract module
pub mod kliver_registry;

// Re-export key types for easier access
pub use types::VerificationResult;