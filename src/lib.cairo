// Kliver Sessions Registry - Main Library Entry Point

// Declare the main contract module
pub mod kliver_sessions_registry;

// Re-export the main interface and structs for easy access
pub use kliver_sessions_registry::{
    IKliverSessionsRegistry,
    IKliverSessionsRegistryDispatcher,
    IKliverSessionsRegistryDispatcherTrait,
    UserStats,
    Interaction,
    CompletedStep,
    StepCompletionStatus
};

// Optional: Export error constants for external use
pub mod errors {
    pub use super::kliver_sessions_registry::Errors::*;
}

// Optional: Export constants for external use
pub mod constants {
    pub use super::kliver_sessions_registry::Constants::*;
}