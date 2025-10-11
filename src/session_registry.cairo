pub use kliver_on_chain::components::session_registry_component::SessionMetadata;
use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Session Registry Interface
#[starknet::interface]
pub trait ISessionRegistry<TContractState> {
    /// Register a session with metadata (only owner)
    fn register_session(ref self: TContractState, metadata: SessionMetadata);
    /// Verify if a session ID matches its expected root hash
    fn verify_session(
        self: @TContractState, session_id: felt252, root_hash: felt252,
    ) -> VerificationResult;
    /// Get session information (returns complete metadata)
    fn get_session_info(self: @TContractState, session_id: felt252) -> SessionMetadata;
    /// Grant access to a session to a specific address (optional: for sales traceability)
    fn grant_access(ref self: TContractState, session_id: felt252, addr: ContractAddress);
    /// Check if an address has access to a session
    fn has_access(self: @TContractState, session_id: felt252, addr: ContractAddress) -> bool;
    /// Get the verifier address
    fn get_verifier_address(self: @TContractState) -> ContractAddress;
    /// Verify a complete proof for a session
    fn verify_complete_session(
        self: @TContractState, full_proof_with_hints: Span<felt252>,
    ) -> Option<Span<u256>>;
    /// Verify a proof with a numeric challenge key (10 digits) and public root hash
    fn verify_proof(
        self: @TContractState, full_proof_with_hints: Span<felt252>, root_hash: felt252, challenge: u64
    ) -> Option<Span<u256>>;
}
