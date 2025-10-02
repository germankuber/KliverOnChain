// Kliver Registry - Main Library Entry Point

// Declare the main contract module
pub mod kliver_registry;

// Re-export the main interface
pub use kliver_registry::{
    IKliverRegistry,
    IKliverRegistryDispatcher,
    IKliverRegistryDispatcherTrait
};

// Optional: Export error constants for external use
pub mod errors {
    pub use super::kliver_registry::Errors::*;
}

// Optional: Export constants for external use
pub mod constants {
    pub use super::kliver_registry::Constants::*;
}