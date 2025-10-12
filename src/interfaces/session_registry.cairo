pub use kliver_on_chain::components::session_registry_component::SessionMetadata;
use starknet::ContractAddress;
use crate::types::VerificationResult;

#[starknet::interface]
pub trait ISessionRegistry<TContractState> {
    fn register_session(ref self: TContractState, metadata: SessionMetadata);
    fn verify_session(self: @TContractState, session_id: felt252, root_hash: felt252) -> VerificationResult;
    fn get_session_info(self: @TContractState, session_id: felt252) -> SessionMetadata;
    fn grant_access(ref self: TContractState, session_id: felt252, addr: ContractAddress);
    fn has_access(self: @TContractState, session_id: felt252, addr: ContractAddress) -> bool;
    fn get_verifier_address(self: @TContractState) -> ContractAddress;
    fn verify_complete_session(self: @TContractState, full_proof_with_hints: Span<felt252>) -> Option<Span<u256>>;
    fn verify_proof(
        self: @TContractState, full_proof_with_hints: Span<felt252>, root_hash: felt252, challenge: u64
    ) -> Option<Span<u256>>;
}

