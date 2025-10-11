#[starknet::component]
pub mod WhitelistComponent {
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    #[storage]
    pub struct Storage {
        // (token_id, simulation_id, wallet) -> bool (whitelisted or not)
        pub whitelist: Map<(u256, felt252, ContractAddress), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AddedToWhitelist: AddedToWhitelist,
        RemovedFromWhitelist: RemovedFromWhitelist,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AddedToWhitelist {
        #[key]
        pub token_id: u256,
        #[key]
        pub wallet: ContractAddress,
        pub simulation_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RemovedFromWhitelist {
        #[key]
        pub token_id: u256,
        #[key]
        pub wallet: ContractAddress,
        pub simulation_id: felt252,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Add a wallet to the whitelist for a specific token and simulation
        fn add_to_whitelist(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            wallet: ContractAddress,
            simulation_id: felt252,
        ) {
            // Add to whitelist
            self.whitelist.entry((token_id, simulation_id, wallet)).write(true);

            // Emit event
            self.emit(AddedToWhitelist { token_id, wallet, simulation_id });
        }

        /// Remove a wallet from the whitelist for a specific token and simulation
        fn remove_from_whitelist(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            wallet: ContractAddress,
            simulation_id: felt252,
        ) {
            // Remove from whitelist (set to false)
            self.whitelist.entry((token_id, simulation_id, wallet)).write(false);

            // Emit event
            self.emit(RemovedFromWhitelist { token_id, wallet, simulation_id });
        }

        /// Check if a wallet is whitelisted for a specific token and simulation
        fn is_whitelisted(
            self: @ComponentState<TContractState>,
            token_id: u256,
            simulation_id: felt252,
            wallet: ContractAddress,
        ) -> bool {
            self.whitelist.entry((token_id, simulation_id, wallet)).read()
        }
    }
}
