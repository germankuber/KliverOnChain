use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Session metadata containing all session information
#[derive(Drop, Serde, Copy, starknet::Event)]
pub struct SessionMetadata {
    #[key]
    pub session_id: felt252,
    pub root_hash: felt252,
    pub simulation_id: felt252,
    pub author: ContractAddress,
    pub score: u32,
}

/// Session Registry Interface
#[starknet::interface]
pub trait ISessionRegistry<TContractState> {
    /// Register a session with metadata (only owner)
    fn register_session(ref self: TContractState, metadata: SessionMetadata);
    /// Verify if a session ID matches its expected root hash
    fn verify_session(self: @TContractState, session_id: felt252, root_hash: felt252) -> VerificationResult;
    /// Get session information (returns complete metadata)
    fn get_session_info(self: @TContractState, session_id: felt252) -> SessionMetadata;
    /// Grant access to a session to a specific address (optional: for sales traceability)
    fn grant_access(ref self: TContractState, session_id: felt252, addr: ContractAddress);
    /// Check if an address has access to a session
    fn has_access(self: @TContractState, session_id: felt252, addr: ContractAddress) -> bool;
}

/// Session Access Granted Event
#[derive(Drop, starknet::Event)]
pub struct SessionAccessGranted {
    #[key]
    pub session_id: felt252,
    pub grantee: ContractAddress,
    pub granted_by: ContractAddress,
}
