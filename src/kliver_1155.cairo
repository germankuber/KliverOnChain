use super::kliver_1155_types::{TokenCreated, TokenDataToCreate, TokenInfo, Simulation, SimulationRegistered, SimulationDataToCreate, SimulationTrait, AddedToWhitelist, RemovedFromWhitelist, TokensClaimed, SessionPayment, SessionPaid, HintPayment, HintPaid};

#[starknet::contract]
mod KliverRC1155 {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::{TokenCreated, TokenDataToCreate, TokenInfo, Simulation, SimulationRegistered, SimulationDataToCreate, SimulationTrait, AddedToWhitelist, RemovedFromWhitelist, TokensClaimed, SessionPayment, SessionPaid, HintPayment, HintPaid};

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
        // (token_id, wallet) -> simulation_id
        whitelist: Map<(u256, ContractAddress), felt252>,
        // (token_id, simulation_id, wallet) -> last_claim_timestamp
        last_claim_timestamp: Map<(u256, felt252, ContractAddress), u64>,
        // session_id -> SessionPayment
        paid_sessions: Map<felt252, SessionPayment>,
        // hint_id -> HintPayment
        paid_hints: Map<felt252, HintPayment>,
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
        AddedToWhitelist: AddedToWhitelist,
        RemovedFromWhitelist: RemovedFromWhitelist,
        TokensClaimed: TokensClaimed,
        SessionPaid: SessionPaid,
        HintPaid: HintPaid,
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

        let current_time = starknet::get_block_timestamp();
        let simulation = SimulationTrait::new(
            simulation_data.simulation_id,
            simulation_data.token_id,
            caller,
            current_time,
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
    fn add_to_whitelist(
        ref self: ContractState,
        token_id: u256,
        wallet: ContractAddress,
        simulation_id: felt252,
    ) {
        // Only owner can add to whitelist
        self._assert_only_owner();

        // Verify token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(
            token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist',
        );

        // Verify simulation exists and belongs to the token
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.token_id == token_id, 'Simulation not for this token');

        // Add to whitelist
        self.whitelist.entry((token_id, wallet)).write(simulation_id);

        self.emit(AddedToWhitelist {
            token_id,
            wallet,
            simulation_id,
        });
    }

    #[external(v0)]
    fn remove_from_whitelist(
        ref self: ContractState,
        token_id: u256,
        wallet: ContractAddress,
    ) {
        // Only owner can remove from whitelist
        self._assert_only_owner();

        // Verify token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(
            token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist',
        );

        // Remove from whitelist (set to 0)
        self.whitelist.entry((token_id, wallet)).write(0);

        self.emit(RemovedFromWhitelist {
            token_id,
            wallet,
        });
    }

    #[external(v0)]
    fn is_whitelisted(
        self: @ContractState,
        token_id: u256,
        wallet: ContractAddress,
    ) -> bool {
        let simulation_id = self.whitelist.entry((token_id, wallet)).read();
        simulation_id != 0
    }

    #[external(v0)]
    fn get_whitelist_simulation(
        self: @ContractState,
        token_id: u256,
        wallet: ContractAddress,
    ) -> felt252 {
        self.whitelist.entry((token_id, wallet)).read()
    }

    #[external(v0)]
    fn claim(
        ref self: ContractState,
        token_id: u256,
        simulation_id: felt252,
    ) {
        let caller = get_caller_address();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        // 1. Verify token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist');

        // 2. Verify simulation exists
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 3. Verify simulation belongs to this token
        assert(simulation.token_id == token_id, 'Simulation not for this token');

        // 4. Verify user is whitelisted for this token and simulation
        let whitelisted_sim = self.whitelist.entry((token_id, caller)).read();
        assert(whitelisted_sim == simulation_id, 'Not whitelisted');

        // 5. Check if simulation is expired
        let current_time = starknet::get_block_timestamp();
        assert(current_time < simulation.expiration_timestamp, 'Simulation has expired');

        // 6. Get last claim timestamp (0 if never claimed)
        let last_claim = self.last_claim_timestamp.entry((token_id, simulation_id, caller)).read();
        let start_time = if last_claim == 0 {
            simulation.creation_timestamp
        } else {
            last_claim
        };

        // 7. Calculate claimable days
        let claimable_days = self.calculate_claimable_days(
            current_time,
            start_time,
            token_info.release_hour
        );

        assert(claimable_days > 0, 'No days available to claim');

        // 8. Calculate total amount to mint
        let total_amount = token_info.release_amount * claimable_days;

        // 9. Mint tokens to claimer
        self.erc1155.mint_with_acceptance_check(
            caller,
            token_id,
            total_amount,
            array![].span()
        );

        // 10. Update last claim timestamp
        self.last_claim_timestamp.entry((token_id, simulation_id, caller)).write(current_time);

        self.emit(TokensClaimed {
            token_id,
            simulation_id,
            claimer: caller,
            amount: total_amount,
        });
    }


    #[external(v0)]
    fn get_claimable_amount(
        self: @ContractState,
        token_id: u256,
        simulation_id: felt252,
        wallet: ContractAddress,
    ) -> u256 {
        let simulation = self.simulations.entry(simulation_id).read();
        let token_info = self.token_info.entry(token_id).read();
        let current_time = starknet::get_block_timestamp();

        let last_claim = self.last_claim_timestamp.entry((token_id, simulation_id, wallet)).read();
        let start_time = if last_claim == 0 {
            simulation.creation_timestamp
        } else {
            last_claim
        };

        let claimable_days = self.calculate_claimable_days(
            current_time,
            start_time,
            token_info.release_hour
        );

        // Return total tokens claimable, not days
        token_info.release_amount * claimable_days
    }

    #[external(v0)]
    fn pay_for_session(
        ref self: ContractState,
        simulation_id: felt252,
        session_id: felt252,
        amount: u256,
    ) {
        let caller = get_caller_address();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        // 1. Verify simulation exists
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 2. Get token_id from simulation
        let token_id = simulation.token_id;

        // 3. Verify caller is whitelisted for this simulation
        let whitelisted_sim = self.whitelist.entry((token_id, caller)).read();
        assert(whitelisted_sim == simulation_id, 'Not whitelisted');

        // 4. Verify simulation has not expired
        let current_time = starknet::get_block_timestamp();
        assert(current_time < simulation.expiration_timestamp, 'Simulation has expired');

        // 5. Check caller has sufficient balance
        let balance = self.erc1155.balance_of(caller, token_id);
        assert(balance >= amount, 'Insufficient balance');

        // 6. Burn tokens from caller
        self.erc1155.burn(caller, token_id, amount);

        // 7. Record session as paid
        let session_payment = SessionPayment {
            session_id,
            simulation_id,
            payer: caller,
            amount,
            timestamp: current_time,
        };
        self.paid_sessions.entry(session_id).write(session_payment);

        // 8. Emit event
        self.emit(SessionPaid {
            session_id,
            simulation_id,
            payer: caller,
            amount,
            token_id,
        });
    }

    #[external(v0)]
    fn is_session_paid(self: @ContractState, session_id: felt252) -> bool {
        let session = self.paid_sessions.entry(session_id).read();
        let zero_address: ContractAddress = 0.try_into().unwrap();
        // If payer is not zero address, session is paid
        session.payer != zero_address
    }

    #[external(v0)]
    fn get_session_payment(self: @ContractState, session_id: felt252) -> SessionPayment {
        self.paid_sessions.entry(session_id).read()
    }

    #[external(v0)]
    fn pay_for_hint(
        ref self: ContractState,
        simulation_id: felt252,
        hint_id: felt252,
        amount: u256,
    ) {
        let caller = get_caller_address();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        // 1. Verify simulation exists
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 2. Get token_id from simulation
        let token_id = simulation.token_id;

        // 3. Verify caller is whitelisted for this simulation
        let whitelisted_sim = self.whitelist.entry((token_id, caller)).read();
        assert(whitelisted_sim == simulation_id, 'Not whitelisted');

        // 4. Verify simulation has not expired
        let current_time = starknet::get_block_timestamp();
        assert(current_time < simulation.expiration_timestamp, 'Simulation has expired');

        // 5. Check caller has sufficient balance
        let balance = self.erc1155.balance_of(caller, token_id);
        assert(balance >= amount, 'Insufficient balance');

        // 6. Burn tokens from caller
        self.erc1155.burn(caller, token_id, amount);

        // 7. Record hint as paid
        let hint_payment = HintPayment {
            hint_id,
            simulation_id,
            payer: caller,
            amount,
            timestamp: current_time,
        };
        self.paid_hints.entry(hint_id).write(hint_payment);

        // 8. Emit event
        self.emit(HintPaid {
            hint_id,
            simulation_id,
            payer: caller,
            amount,
            token_id,
        });
    }

    #[external(v0)]
    fn is_hint_paid(self: @ContractState, hint_id: felt252) -> bool {
        let hint = self.paid_hints.entry(hint_id).read();
        let zero_address: ContractAddress = 0.try_into().unwrap();
        // If payer is not zero address, hint is paid
        hint.payer != zero_address
    }

    #[external(v0)]
    fn get_hint_payment(self: @ContractState, hint_id: felt252) -> HintPayment {
        self.paid_hints.entry(hint_id).read()
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

        fn calculate_claimable_days(
            self: @ContractState,
            current_time: u64,
            start_time: u64,
            release_hour: u64
        ) -> u256 {
            let seconds_per_day: u64 = 86400;
            let seconds_per_hour: u64 = 3600;

            // Calculate full days elapsed since start
            let elapsed_seconds = current_time - start_time;
            let full_days_elapsed = elapsed_seconds / seconds_per_day;

            // Check if today's release hour has passed
            let seconds_today = current_time % seconds_per_day;
            let current_hour = seconds_today / seconds_per_hour;

            // If current hour >= release hour, today's release is available
            let claimable_days: u256 = if current_hour >= release_hour {
                (full_days_elapsed + 1).into()
            } else {
                full_days_elapsed.into()
            };

            claimable_days
        }
    }
}
