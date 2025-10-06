use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Session metadata containing author and score information
#[derive(Drop, Serde, starknet::Store)]
pub struct SessionMetadata {
    pub author: ContractAddress,
    pub score: u32,
}

/// Session information returned by get_session_info
#[derive(Drop, Serde)]
pub struct SessionInfo {
    pub root_hash: felt252,
    pub author: ContractAddress,
    pub score: u32,
}

/// Session Registry Interface
#[starknet::interface]
pub trait ISessionRegistry<TContractState> {
    /// Register a session with its ID, root hash, and metadata (only owner)
    fn register_session(ref self: TContractState, session_id: felt252, root_hash: felt252, metadata: SessionMetadata);
    /// Verify if a session ID matches its expected root hash
    fn verify_session(self: @TContractState, session_id: felt252, root_hash: felt252) -> VerificationResult;
    /// Get session information (root hash, author, and score)
    fn get_session_info(self: @TContractState, session_id: felt252) -> SessionInfo;
    /// Grant access to a session to a specific address (optional: for sales traceability)
    fn grant_access(ref self: TContractState, session_id: felt252, addr: ContractAddress);
    /// Check if an address has access to a session
    fn has_access(self: @TContractState, session_id: felt252, addr: ContractAddress) -> bool;
}

/// Session Registered Event
#[derive(Drop, starknet::Event)]
pub struct SessionRegistered {
    #[key]
    pub session_id: felt252,
    pub root_hash: felt252,
    pub author: ContractAddress,
    pub score: u32,
    pub registered_by: ContractAddress,
}

/// Session Access Granted Event
#[derive(Drop, starknet::Event)]
pub struct SessionAccessGranted {
    #[key]
    pub session_id: felt252,
    pub grantee: ContractAddress,
    pub granted_by: ContractAddress,
}
