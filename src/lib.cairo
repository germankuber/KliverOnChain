// Kliver Registry - Main Library Entry Point

// Declare the main contract module
pub mod kliver_registry;

// Re-export all the interfaces
pub use kliver_registry::{
    // Character Registry
    ICharacterRegistry,
    ICharacterRegistryDispatcher,
    ICharacterRegistryDispatcherTrait,
    
    // Scenario Registry
    IScenarioRegistry,
    IScenarioRegistryDispatcher,
    IScenarioRegistryDispatcherTrait,
    
    // Simulation Registry
    ISimulationRegistry,
    ISimulationRegistryDispatcher,
    ISimulationRegistryDispatcherTrait,
    
    // Owner Registry
    IOwnerRegistry,
    IOwnerRegistryDispatcher,
    IOwnerRegistryDispatcherTrait,
};