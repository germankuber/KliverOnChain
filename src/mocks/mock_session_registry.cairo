#[starknet::contract]
pub mod MockSessionRegistry {
    use kliver_on_chain::components::session_registry_component::SessionMetadata;
    use kliver_on_chain::interfaces::session_registry::ISessionRegistry;
    use kliver_on_chain::types::VerificationResult;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
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
        fn verify_session(
            self: @ContractState, session_id: felt252, root_hash: felt252,
        ) -> VerificationResult {
            let stored_root = self.roots.read(session_id);
            if stored_root == 0 { return VerificationResult::NotFound; }
            if stored_root == root_hash { VerificationResult::Match } else { VerificationResult::Mismatch }
        }
        fn get_session_info(self: @ContractState, session_id: felt252) -> SessionMetadata {
            let root = self.roots.read(session_id);
            assert(root != 0, 'Session not found');
            let sim = self.sims.read(session_id);
            let author = self.authors.read(session_id);
            let score = self.scores.read(session_id);
            SessionMetadata { session_id, root_hash: root, simulation_id: sim, author, score }
        }
        fn grant_access(ref self: ContractState, session_id: felt252, addr: ContractAddress) {
            // no-op for mock
        }
        fn has_access(self: @ContractState, session_id: felt252, addr: ContractAddress) -> bool {
            true
        }
        fn get_verifier_address(self: @ContractState) -> ContractAddress {
            0.try_into().unwrap()
        }
        fn verify_complete_session(self: @ContractState, full_proof_with_hints: Span<felt252>) -> Option<Span<u256>> {
            Option::None(())
        }
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
