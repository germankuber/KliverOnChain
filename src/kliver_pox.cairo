// removed unused top-level import

#[starknet::contract]
mod KliverPox {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::kliver_pox::KliverPoxMetadata;
    use kliver_on_chain::components::session_registry_component::SessionMetadata;
    use crate::types::VerificationResult;

    // Minimal NFT storage and indexing by simulation
    #[storage]
    struct Storage {
        // Owner registry allowed to mint
        registry: ContractAddress,
        // Next token id (starts at 0, first mint -> 1)
        next_token_id: u256,
        // Ownership and balances
        token_owner: Map<u256, ContractAddress>,
        balances: Map<ContractAddress, u256>,
        // Index token -> simulation
        token_to_sim: Map<u256, felt252>,
        // Store root hash per simulation and per token
        root_hash_by_sim: Map<felt252, felt252>,
        root_hash_by_token: Map<u256, felt252>,
        // Store session id and score per token
        session_id_by_token: Map<u256, felt252>,
        score_by_token: Map<u256, u32>,
        // Lookup by session id
        session_to_token: Map<felt252, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Minted: Minted,
    }

    #[derive(Drop, starknet::Event)]
    struct Minted {
        #[key]
        token_id: u256,
        #[key]
        simulation_id: felt252,
        #[key]
        session_id: felt252,
        #[key]
        author: ContractAddress,
        root_hash: felt252,
    }

    pub mod Errors {
        pub const INVALID_REGISTRY: felt252 = 'Invalid registry address';
        pub const ONLY_REGISTRY: felt252 = 'Only registry can call';
        pub const INVALID_AUTHOR: felt252 = 'Invalid author';
        pub const SIM_ALREADY_MINTED: felt252 = 'Simulation already minted';
        pub const TOKEN_NOT_FOUND: felt252 = 'Token not found';
    }

    #[constructor]
    fn constructor(ref self: ContractState, registry_address: ContractAddress) {
        assert(!registry_address.is_zero(), Errors::INVALID_REGISTRY);
        self.registry.write(registry_address);
        self.next_token_id.write(0);
    }

    #[abi(embed_v0)]
    impl KliverPoxImpl of crate::interfaces::kliver_pox::IKliverPox<ContractState> {
        fn mint(ref self: ContractState, metadata: SessionMetadata) {
            // Access control: only configured registry can mint
            let caller = get_caller_address();
            assert(caller == self.registry.read(), Errors::ONLY_REGISTRY);

            // Basic validations
            assert(!metadata.author.is_zero(), Errors::INVALID_AUTHOR);
            // Prevent duplicate mint for the same simulation via token_to_sim scan is not feasible;
            // use session_to_token to ensure uniqueness at session level and proxy uniqueness for simulation by design
            let existing_token = self.session_to_token.read(metadata.session_id);
            assert(existing_token == 0, Errors::SIM_ALREADY_MINTED);

            // New token id = next_token_id + 1
            let next = self.next_token_id.read();
            let token_id = next + 1;
            self.next_token_id.write(token_id);

            // Assign ownership
            self.token_owner.write(token_id, metadata.author);
            let bal = self.balances.read(metadata.author);
            self.balances.write(metadata.author, bal + 1);

            // Index by simulation
            self.token_to_sim.write(token_id, metadata.simulation_id);
            // Store root hash
            self.root_hash_by_sim.write(metadata.simulation_id, metadata.root_hash);
            self.root_hash_by_token.write(token_id, metadata.root_hash);
            // Store session id and score
            self.session_id_by_token.write(token_id, metadata.session_id);
            self.score_by_token.write(token_id, metadata.score);
            self.session_to_token.write(metadata.session_id, token_id);

            // Emit event
            self.emit(Minted {
                token_id,
                simulation_id: metadata.simulation_id,
                session_id: metadata.session_id,
                author: metadata.author,
                root_hash: metadata.root_hash,
            });
        }

        fn balance_of(self: @ContractState, user: ContractAddress) -> u256 {
            self.balances.read(user)
        }

        fn owner_of_token(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.token_owner.read(token_id);
            assert(!owner.is_zero(), Errors::TOKEN_NOT_FOUND);
            owner
        }

        // owner_of_simulation removed (no sim_to_token mapping)

        fn get_metadata_by_token(self: @ContractState, token_id: u256) -> KliverPoxMetadata {
            let author = self.token_owner.read(token_id);
            assert(!author.is_zero(), Errors::TOKEN_NOT_FOUND);
            let simulation_id = self.token_to_sim.read(token_id);
            let session_id = self.session_id_by_token.read(token_id);
            let root_hash = self.root_hash_by_token.read(token_id);
            let score_u32 = self.score_by_token.read(token_id);
            KliverPoxMetadata {
                token_id,
                session_id,
                root_hash,
                simulation_id,
                author,
                score: score_u32,
            }
        }

        fn get_metadata_by_session(self: @ContractState, session_id: felt252) -> KliverPoxMetadata {
            let token_id = self.session_to_token.read(session_id);
            assert(token_id != 0, 'Session not found');
            self.get_metadata_by_token(token_id)
        }

        fn has_session(self: @ContractState, session_id: felt252) -> bool {
            let token_id = self.session_to_token.read(session_id);
            token_id != 0
        }

        fn verify_session_by_token(self: @ContractState, token_id: u256, root_hash: felt252) -> VerificationResult {
            let stored_root = self.root_hash_by_token.read(token_id);
            if stored_root == 0 {
                VerificationResult::NotFound
            } else if stored_root == root_hash {
                VerificationResult::Match
            } else {
                VerificationResult::Mismatch
            }
        }

        fn verify_session_by_session_id(self: @ContractState, session_id: felt252, root_hash: felt252) -> VerificationResult {
            let token_id = self.session_to_token.read(session_id);
            if token_id == 0 {
                VerificationResult::NotFound
            } else {
                let stored_root = self.root_hash_by_token.read(token_id);
                if stored_root == root_hash {
                    VerificationResult::Match
                } else {
                    VerificationResult::Mismatch
                }
            }
        }

        fn get_registry_address(self: @ContractState) -> ContractAddress {
            self.registry.read()
        }
    }
}
