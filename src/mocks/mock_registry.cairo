#[starknet::contract]
pub mod MockRegistry {
    use kliver_on_chain::interfaces::session_registry::ISessionRegistry;
    use kliver_on_chain::components::session_registry_component::SessionMetadata;
    
    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl SessionRegistryImpl of ISessionRegistry<ContractState> {
        fn register_session(ref self: ContractState, metadata: SessionMetadata) {
            // Mock implementation - does nothing
        }
        
        fn verify_proof(
            self: @ContractState, 
            full_proof_with_hints: Span<felt252>, 
            root_hash: felt252, 
            challenge: u64
        ) -> Option<Span<u256>> {
            // Return Some if non-empty proof, else None (simulating verification success)
            if full_proof_with_hints.len() > 0 {
                let arr: Array<u256> = array![1, 2, 3];
                Option::Some(arr.span())
            } else {
                Option::None(())
            }
        }
    }
}
