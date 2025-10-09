use super::kliver_1155_types::{TokenCreated, TokenDataToCreate, TokenInfo, Simulation, SimulationRegistered, SimulationDataToCreate, SimulationTrait};

#[starknet::contract]
mod KliverRC1155 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::{TokenCreated, TokenDataToCreate, TokenInfo, Simulation, SimulationRegistered, SimulationDataToCreate, SimulationTrait};

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl ERC1155HooksImpl = ERC1155HooksEmptyImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        owner: ContractAddress,
        token_info: Map<u256, TokenInfo>,
        next_token_id: u256,
        simulations: Map<felt252, Simulation>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TokenCreated: TokenCreated,
        SimulationRegistered: SimulationRegistered,
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, base_uri: ByteArray) {
        assert(owner != 0.try_into().unwrap(), 'Owner cannot be zero');
        self.owner.write(owner);
        self.erc1155.initializer(base_uri);
        self.next_token_id.write(1);
    }

    #[external(v0)]
    fn create_token(ref self: ContractState, token_data: TokenDataToCreate) -> u256 {
        self._assert_only_owner();

        let token_id = self.next_token_id.read();

        let token_info = TokenInfo {
            release_hour: token_data.release_hour, release_amount: token_data.release_amount,
        };

        self.token_info.entry(token_id).write(token_info);
        self.next_token_id.write(token_id + 1);

        self
            .emit(
                TokenCreated {
                    token_id,
                    creator: get_caller_address(),
                    release_hour: token_data.release_hour,
                    release_amount: token_data.release_amount,
                },
            );

        token_id
    }

    #[external(v0)]
    fn time_until_release(self: @ContractState, token_id: u256) -> u64 {
        // First validate that the token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(
            token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist',
        );

        let current_time = starknet::get_block_timestamp();

        // Seconds in a day and in an hour
        let seconds_per_day: u64 = 86400;
        let seconds_per_hour: u64 = 3600;

        // Calculate seconds elapsed since start of current day
        let seconds_today = current_time % seconds_per_day;

        // Calculate seconds until release hour
        let release_seconds = token_info.release_hour * seconds_per_hour;

        if seconds_today < release_seconds {
            // Release is today
            release_seconds - seconds_today
        } else {
            // Release is tomorrow
            seconds_per_day - seconds_today + release_seconds
        }
    }

    #[external(v0)]
    fn get_token_info(self: @ContractState, token_id: u256) -> TokenInfo {
        self.token_info.entry(token_id).read()
    }

    #[external(v0)]
    fn register_simulation(
        ref self: ContractState,
        simulation_data: SimulationDataToCreate,
    ) -> felt252 {
        self._assert_only_owner();

        // Check if token exists by verifying token info is not zero
        let token_info = self.token_info.entry(simulation_data.token_id).read();
        assert(token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist');

        let caller = get_caller_address();

        let simulation = SimulationTrait::new(
            simulation_data.simulation_id,
            simulation_data.token_id,
            caller,
            simulation_data.expiration_timestamp,
        );

        self.simulations.entry(simulation_data.simulation_id).write(simulation);

        self.emit(SimulationRegistered {
            simulation_id: simulation_data.simulation_id,
            token_id: simulation_data.token_id,
            creator: caller,
            expiration_timestamp: simulation_data.expiration_timestamp,
        });

        simulation_data.simulation_id
    }

    #[external(v0)]
    fn get_simulation(self: @ContractState, simulation_id: felt252) -> Simulation {
        self.simulations.entry(simulation_id).read()
    }

    #[external(v0)]
    fn is_simulation_expired(self: @ContractState, simulation_id: felt252) -> bool {
        let simulation = self.simulations.entry(simulation_id).read();
        let current_time = starknet::get_block_timestamp();
        current_time >= simulation.expiration_timestamp
    }

    #[external(v0)]
    fn get_owner(self: @ContractState) -> ContractAddress {
        self.owner.read()
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Not owner');
        }
    }
}
