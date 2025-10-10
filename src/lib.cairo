// Kliver Registry - Main Library Entry Point
// This modular structure separates concerns by registry type for better maintainability

// Common types module

// Components module
pub mod components {
    pub mod whitelist_component;
    pub mod character_registry_component;
    pub mod scenario_registry_component;
    pub mod simulation_registry_component;
    pub mod session_registry_component;
}

// Registry interface modules - separated by functionality
pub mod character_registry;
pub mod kliver_tokens_core;
pub mod kliver_tokens_core_interface;
pub mod kliver_tokens_core_types;
// NFT modules
pub mod kliver_nft;

// Main contract module
pub mod kliver_registry;
pub mod owner_registry;
pub mod scenario_registry;
pub mod session_registry;
pub mod sessions_marketplace;
pub mod simulation_registry;
pub mod types;


// Re-export key types for easier access
pub use types::VerificationResult;

