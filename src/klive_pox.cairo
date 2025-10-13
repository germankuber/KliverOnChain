use starknet::ContractAddress;

#[starknet::contract]
mod KlivePox {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};

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
        fn mint(
            ref self: ContractState,
            simulation_id: felt252,
            author: ContractAddress,
            character_id: felt252,
            scenario_id: felt252,
            simulation_hash: felt252,
        ) {
            // Access control: only configured registry can mint
            let caller = get_caller_address();
            assert(caller == self.registry.read(), Errors::ONLY_REGISTRY);

            // Basic validations
            assert(!author.is_zero(), Errors::INVALID_AUTHOR);
            // Prevent duplicate mint for the same simulation
            let existing = self.sim_to_token.read(simulation_id);
            assert(existing == 0, Errors::SIM_ALREADY_MINTED);

            // New token id = next_token_id + 1
            let next = self.next_token_id.read();
            let token_id = next + 1;
            self.next_token_id.write(token_id);

            // Assign ownership
            self.token_owner.write(token_id, author);
            let bal = self.balances.read(author);
            self.balances.write(author, bal + 1);

            // Index by simulation
            self.sim_to_token.write(simulation_id, token_id);
            self.token_to_sim.write(token_id, simulation_id);

            // Note: character_id, scenario_id, simulation_hash are accepted but kept internal-only for now
            // (Future: store if needed for additional getters)
            let _ = character_id;
            let _ = scenario_id;
            let _ = simulation_hash;
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
    }
}
