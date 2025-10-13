use starknet::ContractAddress;

#[starknet::contract]
mod KlivePox {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::klive_pox::KlivePoxMetadata;
    use kliver_on_chain::components::session_registry_component::SessionMetadata;

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
        // Index simulation -> token and token -> simulation
        sim_to_token: Map<felt252, u256>,
        token_to_sim: Map<u256, felt252>,
        // Store root hash per simulation and per token
        root_hash_by_sim: Map<felt252, felt252>,
        root_hash_by_token: Map<u256, felt252>,
        // Store session id and score per token
        session_id_by_token: Map<u256, felt252>,
        score_by_token: Map<u256, u32>,
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
    impl KlivePoxImpl of crate::interfaces::klive_pox::IKlivePox<ContractState> {
        fn mint(ref self: ContractState, metadata: SessionMetadata) {
            // Access control: only configured registry can mint
            let caller = get_caller_address();
            assert(caller == self.registry.read(), Errors::ONLY_REGISTRY);

            // Basic validations
            assert(!metadata.author.is_zero(), Errors::INVALID_AUTHOR);
            // Prevent duplicate mint for the same simulation
            let existing = self.sim_to_token.read(metadata.simulation_id);
            assert(existing == 0, Errors::SIM_ALREADY_MINTED);

            // New token id = next_token_id + 1
            let next = self.next_token_id.read();
            let token_id = next + 1;
            self.next_token_id.write(token_id);

            // Assign ownership
            self.token_owner.write(token_id, metadata.author);
            let bal = self.balances.read(metadata.author);
            self.balances.write(metadata.author, bal + 1);

            // Index by simulation
            self.sim_to_token.write(metadata.simulation_id, token_id);
            self.token_to_sim.write(token_id, metadata.simulation_id);
            // Store root hash
            self.root_hash_by_sim.write(metadata.simulation_id, metadata.root_hash);
            self.root_hash_by_token.write(token_id, metadata.root_hash);
            // Store session id and score
            self.session_id_by_token.write(token_id, metadata.session_id);
            self.score_by_token.write(token_id, metadata.score);

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

        fn owner_of_simulation(self: @ContractState, simulation_id: felt252) -> ContractAddress {
            let token_id = self.sim_to_token.read(simulation_id);
            if token_id == 0 {
                return 0.try_into().unwrap();
            }
            let owner = self.token_owner.read(token_id);
            owner
        }

        fn get_metadata_by_token(self: @ContractState, token_id: u256) -> KlivePoxMetadata {
            let author = self.token_owner.read(token_id);
            assert(!author.is_zero(), Errors::TOKEN_NOT_FOUND);
            let simulation_id = self.token_to_sim.read(token_id);
            let session_id = self.session_id_by_token.read(token_id);
            let root_hash = self.root_hash_by_token.read(token_id);
            let score_u32 = self.score_by_token.read(token_id);
            KlivePoxMetadata {
                token_id,
                session_id,
                root_hash,
                simulation_id,
                author,
                score: score_u32,
            }
        }

        fn get_metadata_by_simulation(self: @ContractState, simulation_id: felt252) -> KlivePoxMetadata {
            let token_id = self.sim_to_token.read(simulation_id);
            assert(token_id != 0, 'Simulation not found');
            self.get_metadata_by_token(token_id)
        }
    }
}
