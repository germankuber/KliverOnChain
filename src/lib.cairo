// Kliver Registry - Main Library Entry Point
// This modular structure separates concerns by registry type for better maintainability

// Common types module

// Components module
pub mod components {
    pub mod character_registry_component;
    pub mod scenario_registry_component;
    pub mod session_registry_component;
    pub mod simulation_registry_component;
    pub mod whitelist_component;
}

// Registry interface modules - separated by functionality
pub mod character_registry;
// NFT modules
pub mod kliver_nft;
pub mod pox_nft;

// Main contract module
pub mod kliver_registry;
pub mod kliver_tokens_core;
pub mod kliver_tokens_core_interface;
pub mod kliver_tokens_core_types;
pub mod owner_registry;
pub mod scenario_registry;
pub mod session_escrow;
pub mod session_marketplace;
pub mod session_registry;
pub mod sessions_marketplace;
pub mod simulation_registry;
pub mod types;
pub mod interfaces {
    pub mod payment_token;
}
pub mod mocks {
    pub mod mock_erc20;
    pub mod mock_session_registry;
    pub mod mock_verifier;
}


// Re-export key types for easier access
pub use types::VerificationResult;
