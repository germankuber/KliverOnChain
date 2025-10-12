#[starknet::interface]
pub trait IVerifier<TContractState> {
    fn verify_ultra_starknet_honk_proof(self: @TContractState, full_proof_with_hints: Span<felt252>) -> Option<Span<u256>>;
}

