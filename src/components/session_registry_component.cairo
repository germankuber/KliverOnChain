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
    use super::SessionMetadata;

    #[storage]
    pub struct Storage {
        // Session data is now stored in KliverPox, not here
        // This component is kept minimal for backward compatibility
    }
    use super::SessionAccessGranted;

    #[derive(Drop, starknet::Event)]
    pub struct ProofVerificationEvent {
        pub root_hash: felt252,
        pub challenge: u64,
        pub verified: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SessionRegistered: SessionMetadata,
        SessionAccessGranted: SessionAccessGranted,
        ProofVerified: ProofVerificationEvent,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Emit a ProofVerificationEvent from the component
        fn emit_proof_verified(
            ref self: ComponentState<TContractState>, root_hash: felt252, challenge: u64, verified: bool,
        ) {
            self.emit(ProofVerificationEvent { root_hash, challenge, verified });
        }

        // Note: Session data is now stored in KliverPox contract, not in this component.
        // This component is kept minimal for backward compatibility with existing interfaces.
        // All session queries should be directed to KliverPox contract.
    }
}
