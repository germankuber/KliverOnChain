#[starknet::contract]
pub mod MockSessionRegistry {
    use kliver_on_chain::components::session_registry_component::SessionMetadata;
    use kliver_on_chain::interfaces::session_registry::ISessionRegistry;
    use starknet::storage::{Map, StorageMapWriteAccess};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        roots: Map<felt252, felt252>,
        sims: Map<felt252, felt252>,
        authors: Map<felt252, ContractAddress>,
        scores: Map<felt252, u32>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl RegistryImpl of ISessionRegistry<ContractState> {
        fn register_session(ref self: ContractState, metadata: SessionMetadata) {
            self.roots.write(metadata.session_id, metadata.root_hash);
            self.sims.write(metadata.session_id, metadata.simulation_id);
            self.authors.write(metadata.session_id, metadata.author);
            self.scores.write(metadata.session_id, metadata.score);
        }
        // removed: get_session_info, grant_access, has_access
        fn verify_proof(self: @ContractState, full_proof_with_hints: Span<felt252>, root_hash: felt252, challenge: u64) -> Option<Span<u256>> {
            assert(challenge >= 1000000000_u64, 'Invalid challenge');
            assert(challenge <= 9999999999_u64, 'Invalid challenge');
            if full_proof_with_hints.len() > 0 {
                let arr: Array<u256> = array![1, 2, 3];
                Option::Some(arr.span())
            } else {
                Option::None(())
            }
        }
    }
}
