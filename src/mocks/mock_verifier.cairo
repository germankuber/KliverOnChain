#[starknet::contract]
pub mod MockVerifier {
    use kliver_on_chain::interfaces::verifier::IVerifier;
    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl VerifierImpl of IVerifier<ContractState> {
        fn verify_ultra_starknet_honk_proof(
            self: @ContractState, full_proof_with_hints: Span<felt252>,
        ) -> Option<Span<u256>> {
            // Return Some if non-empty proof, else None
            if full_proof_with_hints.len() > 0 {
                let arr: Array<u256> = array![1, 2, 3];
                Option::Some(arr.span())
            } else {
                Option::None(())
            }
        }
    }

}
