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

// Interfaces (available early for downstream modules)
pub mod interfaces {
    pub mod payment_token;
    pub mod character_registry;
    pub mod owner_registry;
    pub mod scenario_registry;
    pub mod session_registry;
    pub mod simulation_registry;
    pub mod marketplace_interface;
    pub mod session_escrow;
    pub mod kliver_nft;
    pub mod verifier;
    pub mod token_core;
    pub mod erc20;
    pub mod kliver_tokens_core;
    pub mod kliver_pox;
}

// Registry interface modules - separated by functionality
// NFT modules
pub mod kliver_nft;

// Main contract module
pub mod kliver_registry;
pub mod kliver_pox;
pub mod kliver_tokens_core;
pub mod kliver_tokens_core_types;
// interfaces-only modules removed: now under interfaces/*
pub mod session_escrow;
pub mod sessions_marketplace;
pub mod types;
pub mod mocks {
    pub mod mock_erc20;
    pub mod mock_session_registry;
    pub mod mock_verifier;
}

// Demo module - Examples and simple implementations
pub mod demo;


// Re-export key types for easier access
pub use types::VerificationResult;
