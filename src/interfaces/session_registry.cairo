pub use kliver_on_chain::components::session_registry_component::SessionMetadata;

#[starknet::interface]
pub trait ISessionRegistry<TContractState> {
    fn register_session(ref self: TContractState, metadata: SessionMetadata);
    fn verify_proof(
        self: @TContractState, full_proof_with_hints: Span<felt252>, root_hash: felt252, challenge: u64
    ) -> Option<Span<u256>>;
}
