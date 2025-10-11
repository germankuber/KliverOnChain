use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, starknet::Event)]
pub struct SessionMetadata {
    #[key]
    pub session_id: felt252,
    pub root_hash: felt252,
    pub simulation_id: felt252,
    pub author: ContractAddress,
    pub score: u32,
}

#[derive(Drop, starknet::Event)]
pub struct SessionAccessGranted {
    #[key]
    pub session_id: felt252,
    pub grantee: ContractAddress,
    pub granted_by: ContractAddress,
}

#[starknet::component]
pub mod SessionRegistryComponent {
    use kliver_on_chain::types::VerificationResult;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::SessionMetadata;

    #[storage]
    pub struct Storage {
        /// Session data
        pub session_roots: Map<felt252, felt252>,
        pub session_simulations: Map<felt252, felt252>,
        pub session_authors: Map<felt252, ContractAddress>,
        pub session_scores: Map<felt252, u32>,
        pub session_access: Map<(felt252, ContractAddress), bool>,
    }
    use super::SessionAccessGranted;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SessionRegistered: SessionMetadata,
        SessionAccessGranted: SessionAccessGranted,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Register a session
        fn register_session(
            ref self: ComponentState<TContractState>,
            session_id: felt252,
            root_hash: felt252,
            simulation_id: felt252,
            author: ContractAddress,
            score: u32,
        ) {
            // Store session data
            self.session_roots.entry(session_id).write(root_hash);
            self.session_simulations.entry(session_id).write(simulation_id);
            self.session_authors.entry(session_id).write(author);
            self.session_scores.entry(session_id).write(score);

            // Emit event
            self.emit(SessionMetadata { session_id, root_hash, simulation_id, author, score });
        }

        /// Verify if a session ID matches its expected root hash
        fn verify_session(
            self: @ComponentState<TContractState>, session_id: felt252, root_hash: felt252,
        ) -> VerificationResult {
            let stored_root = self.session_roots.entry(session_id).read();

            if stored_root == 0 {
                VerificationResult::NotFound
            } else if stored_root == root_hash {
                VerificationResult::Match
            } else {
                VerificationResult::Mismatch
            }
        }

        /// Get complete session information
        fn get_session_info(
            self: @ComponentState<TContractState>, session_id: felt252,
        ) -> SessionMetadata {
            let root_hash = self.session_roots.entry(session_id).read();
            assert(root_hash != 0, 'Session not found');
            let simulation_id = self.session_simulations.entry(session_id).read();
            let author = self.session_authors.entry(session_id).read();
            let score = self.session_scores.entry(session_id).read();

            SessionMetadata { session_id, root_hash, simulation_id, author, score }
        }

        /// Grant access to a session to a specific address
        fn grant_access(
            ref self: ComponentState<TContractState>,
            session_id: felt252,
            grantee: ContractAddress,
            granted_by: ContractAddress,
        ) {
            // Grant access
            self.session_access.entry((session_id, grantee)).write(true);

            // Emit event
            self.emit(SessionAccessGranted { session_id, grantee, granted_by });
        }

        /// Check if an address has access to a session
        fn has_access(
            self: @ComponentState<TContractState>, session_id: felt252, addr: ContractAddress,
        ) -> bool {
            self.session_access.entry((session_id, addr)).read()
        }

        /// Check if a session exists
        fn session_exists(self: @ComponentState<TContractState>, session_id: felt252) -> bool {
            self.session_roots.entry(session_id).read() != 0
        }

        /// Get session simulation ID
        fn get_session_simulation(
            self: @ComponentState<TContractState>, session_id: felt252,
        ) -> felt252 {
            self.session_simulations.entry(session_id).read()
        }
    }
}
