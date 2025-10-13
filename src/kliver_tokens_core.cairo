use super::kliver_tokens_core_types::{
    ClaimableAmountResult, HintPaid, HintPayment, RegistryAddressUpdated, SessionPaid,
    SessionPayment, Simulation, SimulationClaimData, SimulationExpirationUpdated,
    SimulationRegistered, SimulationTrait, TokenCreated, TokenInfo, TokensClaimed,
    WalletMultiTokenSummary, WalletTokenSummary,
};


#[starknet::contract]
mod KliverTokensCore {
    use kliver_on_chain::components::whitelist_component::WhitelistComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::{
        ClaimableAmountResult, HintPaid, HintPayment, RegistryAddressUpdated, SessionPaid,
        SessionPayment, Simulation, SimulationClaimData, SimulationExpirationUpdated,
        SimulationRegistered, SimulationTrait, TokenCreated, TokenInfo, TokensClaimed,
        WalletMultiTokenSummary, WalletTokenSummary,
    };

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: WhitelistComponent, storage: whitelist, event: WhitelistEvent);

    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;

    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;
    impl ERC1155HooksImpl = ERC1155HooksEmptyImpl<ContractState>;
    impl WhitelistInternalImpl = WhitelistComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        whitelist: WhitelistComponent::Storage,
        owner: ContractAddress,
        registry_address: ContractAddress,
        token_info: Map<u256, TokenInfo>,
        next_token_id: u256,
        simulations: Map<felt252, Simulation>,
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
        #[flat]
        WhitelistEvent: WhitelistComponent::Event,
        TokenCreated: TokenCreated,
        SimulationRegistered: SimulationRegistered,
        SimulationExpirationUpdated: SimulationExpirationUpdated,
        TokensClaimed: TokensClaimed,
        SessionPaid: SessionPaid,
        HintPaid: HintPaid,
        RegistryAddressUpdated: RegistryAddressUpdated,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, base_uri: ByteArray) {
        assert(owner != 0.try_into().unwrap(), 'Owner cannot be zero');
        self.owner.write(owner);
        self.erc1155.initializer(base_uri);
        self.next_token_id.write(1);
        // Registry address inicialmente a zero, será configurado después
        self.registry_address.write(0.try_into().unwrap());
    }

    #[external(v0)]
    fn set_registry_address(ref self: ContractState, new_registry_address: ContractAddress) {
        // Solo el owner puede setear/actualizar la dirección del registry
        self._assert_only_owner();

        // Validar que la nueva dirección no sea zero
        assert(new_registry_address != 0.try_into().unwrap(), 'Registry cannot be zero');

        // Guardar la dirección anterior para el evento
        let old_address = self.registry_address.read();

        // Actualizar la dirección del registry
        self.registry_address.write(new_registry_address);

        // Emitir evento
        self.emit(RegistryAddressUpdated { old_address, new_address: new_registry_address });
    }

    #[external(v0)]
    fn get_registry_address(self: @ContractState) -> ContractAddress {
        self.registry_address.read()
    }

    #[external(v0)]
    fn create_token(
        ref self: ContractState, release_hour: u64, release_amount: u256, special_release: u256,
    ) -> u256 {
        self._assert_only_owner();

        // Validate release_hour is valid (0-23)
        assert(release_hour < 24, 'Invalid release hour');

        // Validate at least one release mechanism exists
        assert(release_amount > 0 || special_release > 0, 'No release amount set');

        let token_id = self.next_token_id.read();

        let token_info = TokenInfo { release_hour, release_amount, special_release };

        self.token_info.entry(token_id).write(token_info);
        self.next_token_id.write(token_id + 1);

        self
            .emit(
                TokenCreated {
                    token_id,
                    creator: get_caller_address(),
                    release_hour,
                    release_amount,
                    special_release,
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
        ref self: ContractState, simulation_id: felt252, token_id: u256, expiration_timestamp: u64,
    ) -> felt252 {
        // Solo el registry puede registrar simulaciones
        self._assert_only_registry();

        // Verify that the token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(
            token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist',
        );

        let caller = get_caller_address();
        let current_time = starknet::get_block_timestamp();

        // NORMALIZE TO MIDNIGHT (00:00 of the current day)
        let seconds_per_day: u64 = 86400;
        let creation_timestamp_midnight = (current_time / seconds_per_day) * seconds_per_day;

        let simulation = SimulationTrait::new(
            simulation_id,
            token_id,
            caller,
            creation_timestamp_midnight, // ← SIEMPRE medianoche
            expiration_timestamp,
        );

        self.simulations.entry(simulation_id).write(simulation);

        self
            .emit(
                SimulationRegistered {
                    simulation_id, token_id, creator: caller, expiration_timestamp,
                },
            );

        simulation_id
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
    fn update_simulation_expiration(
        ref self: ContractState, simulation_id: felt252, new_expiration_timestamp: u64,
    ) {
        // 1. Only owner can update
        self._assert_only_owner();

        // 2. Get simulation and verify it exists
        let mut simulation = self.simulations.entry(simulation_id).read();
        let zero_address: ContractAddress = 0.try_into().unwrap();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 3. Validate new expiration is in the future
        let current_time = starknet::get_block_timestamp();
        assert(new_expiration_timestamp > current_time, 'Expiration must be future');

        // 4. Store old expiration for event
        let old_expiration = simulation.expiration_timestamp;

        // 5. Update expiration
        simulation.expiration_timestamp = new_expiration_timestamp;
        self.simulations.entry(simulation_id).write(simulation);

        // 6. Emit event
        self
            .emit(
                SimulationExpirationUpdated {
                    simulation_id, old_expiration, new_expiration: new_expiration_timestamp,
                },
            );
    }

    #[external(v0)]
    fn add_to_whitelist(
        ref self: ContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252,
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

        // Add to whitelist using component
        self.whitelist.add_to_whitelist(token_id, wallet, simulation_id);
    }

    #[external(v0)]
    fn remove_from_whitelist(
        ref self: ContractState, token_id: u256, wallet: ContractAddress, simulation_id: felt252,
    ) {
        // Only owner can remove from whitelist
        self._assert_only_owner();

        // Verify token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(
            token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist',
        );

        // Remove from whitelist using component
        self.whitelist.remove_from_whitelist(token_id, wallet, simulation_id);
    }

    #[external(v0)]
    fn is_whitelisted(
        self: @ContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress,
    ) -> bool {
        self.whitelist.is_whitelisted(token_id, simulation_id, wallet)
    }

    #[external(v0)]
    fn claim(ref self: ContractState, token_id: u256, simulation_id: felt252) {
        let caller = get_caller_address();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        // 1. Verify token exists
        let token_info = self.token_info.entry(token_id).read();
        assert(
            token_info.release_hour != 0 || token_info.release_amount != 0, 'Token does not exist',
        );

        // 2. Verify simulation exists
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 3. Verify simulation belongs to this token
        assert(simulation.token_id == token_id, 'Simulation not for this token');

        // 4. Verify user is whitelisted for this token and simulation
        let is_whitelisted = self.whitelist.is_whitelisted(token_id, simulation_id, caller);
        assert(is_whitelisted, 'Not whitelisted');

        // 5. Check if simulation is expired
        let current_time = starknet::get_block_timestamp();
        assert(current_time < simulation.expiration_timestamp, 'Simulation has expired');

        // 6. Get last claim timestamp (0 if never claimed)
        let last_claim = self.last_claim_timestamp.entry((token_id, simulation_id, caller)).read();

        // 7. Calculate amount to mint
        let total_amount = if last_claim == 0 {
            // FIRST CLAIM: special_release + normal days
            let special_amount = token_info.special_release;

            // Calculate normal days available
            let normal_days = self
                .calculate_claimable_days(
                    current_time, simulation.creation_timestamp, token_info.release_hour,
                );
            let normal_amount = token_info.release_amount * normal_days;

            special_amount + normal_amount
        } else {
            // SUBSEQUENT CLAIMS: only normal days (no special)

            // Total claimable days until now (always from creation_timestamp)
            let total_claimable_days = self
                .calculate_claimable_days(
                    current_time, simulation.creation_timestamp, token_info.release_hour,
                );

            // Days already claimed in last claim (always from creation_timestamp)
            let days_already_claimed = self
                .calculate_claimable_days(
                    last_claim, simulation.creation_timestamp, token_info.release_hour,
                );

            // Calculate only new days
            assert(total_claimable_days > days_already_claimed, 'Nothing to claim yet');
            let new_days = total_claimable_days - days_already_claimed;

            token_info.release_amount * new_days
        };

        assert(total_amount > 0, 'Nothing to claim');

        // 8. Mint tokens to claimer
        // self.erc1155.mint_with_acceptance_check(caller, token_id, total_amount, array![].span());

        let zero_address: ContractAddress = 0.try_into().unwrap();
        self
            .erc1155
            .update(zero_address, caller, array![token_id].span(), array![total_amount].span());

        // 9. Update last claim timestamp
        self.last_claim_timestamp.entry((token_id, simulation_id, caller)).write(current_time);

        self.emit(TokensClaimed { token_id, simulation_id, claimer: caller, amount: total_amount });
    }


    #[external(v0)]
    fn get_claimable_amount(
        self: @ContractState, token_id: u256, simulation_id: felt252, wallet: ContractAddress,
    ) -> u256 {
        let simulation = self.simulations.entry(simulation_id).read();
        let token_info = self.token_info.entry(token_id).read();
        let current_time = starknet::get_block_timestamp();
        let last_claim = self.last_claim_timestamp.entry((token_id, simulation_id, wallet)).read();

        if last_claim == 0 {
            // FIRST CLAIM: special_release + normal days
            let special_amount = token_info.special_release;

            let normal_days = self
                .calculate_claimable_days(
                    current_time, simulation.creation_timestamp, token_info.release_hour,
                );
            let normal_amount = token_info.release_amount * normal_days;

            special_amount + normal_amount
        } else {
            // Total claimable days until now
            let total_claimable_days = self
                .calculate_claimable_days(
                    current_time, simulation.creation_timestamp, token_info.release_hour,
                );

            // Days already claimed
            let days_already_claimed = self
                .calculate_claimable_days(
                    last_claim, simulation.creation_timestamp, token_info.release_hour,
                );

            // Calculate only new days (return 0 if nothing new)
            if total_claimable_days > days_already_claimed {
                let new_days = total_claimable_days - days_already_claimed;
                token_info.release_amount * new_days
            } else {
                0
            }
        }
    }

    #[external(v0)]
    fn get_claimable_amounts_batch(
        self: @ContractState,
        token_id: u256,
        simulation_ids: Span<felt252>,
        wallets: Span<ContractAddress>,
    ) -> Array<ClaimableAmountResult> {
        let mut results: Array<ClaimableAmountResult> = ArrayTrait::new();
        let token_info = self.token_info.entry(token_id).read();
        let current_time = starknet::get_block_timestamp();

        // Iterate through all simulation_ids
        let mut i: u32 = 0;
        while i < simulation_ids.len() {
            let simulation_id = *simulation_ids.at(i);
            let simulation = self.simulations.entry(simulation_id).read();

            // Iterate through all wallets for this simulation
            let mut j: u32 = 0;
            while j < wallets.len() {
                let wallet = *wallets.at(j);
                let last_claim = self
                    .last_claim_timestamp
                    .entry((token_id, simulation_id, wallet))
                    .read();

                let amount = if last_claim == 0 {
                    // FIRST CLAIM: special_release + normal days
                    let special_amount = token_info.special_release;

                    let normal_days = self
                        .calculate_claimable_days(
                            current_time, simulation.creation_timestamp, token_info.release_hour,
                        );
                    let normal_amount = token_info.release_amount * normal_days;

                    special_amount + normal_amount
                } else {
                    // Total claimable days until now
                    let total_claimable_days = self
                        .calculate_claimable_days(
                            current_time, simulation.creation_timestamp, token_info.release_hour,
                        );

                    // Days already claimed
                    let days_already_claimed = self
                        .calculate_claimable_days(
                            last_claim, simulation.creation_timestamp, token_info.release_hour,
                        );

                    // Calculate only new days (return 0 if nothing new)
                    if total_claimable_days > days_already_claimed {
                        let new_days = total_claimable_days - days_already_claimed;
                        token_info.release_amount * new_days
                    } else {
                        0
                    }
                };

                results.append(ClaimableAmountResult { simulation_id, wallet, amount });

                j += 1;
            }

            i += 1;
        }

        results
    }

    #[external(v0)]
    fn get_wallet_token_summary(
        self: @ContractState,
        token_id: u256,
        wallet: ContractAddress,
        simulation_ids: Span<felt252>,
    ) -> WalletTokenSummary {
        self._get_wallet_token_summary_internal(token_id, wallet, simulation_ids)
    }

    #[external(v0)]
    fn get_wallet_simulations_summary(
        self: @ContractState, wallet: ContractAddress, simulation_ids: Span<felt252>,
    ) -> WalletMultiTokenSummary {
        // Step 1: Identificar todos los tokens únicos de las simulaciones
        let mut unique_tokens: Array<u256> = ArrayTrait::new();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        let mut i: u32 = 0;
        while i < simulation_ids.len() {
            let simulation_id = *simulation_ids.at(i);
            let simulation = self.simulations.entry(simulation_id).read();

            // Verificar que la simulación existe
            if simulation.creator != zero_address {
                let token_id = simulation.token_id;

                // Verificar si este token ya está en la lista
                let mut already_exists = false;
                let mut j: u32 = 0;
                while j < unique_tokens.len() {
                    if *unique_tokens.at(j) == token_id {
                        already_exists = true;
                        break;
                    }
                    j += 1;
                }

                // Si no existe, agregarlo
                if !already_exists {
                    unique_tokens.append(token_id);
                }
            }

            i += 1;
        }

        // Step 2: Para cada token, recopilar las simulaciones y calcular el summary
        let mut tokens_summary: Array<WalletTokenSummary> = ArrayTrait::new();

        let mut token_idx: u32 = 0;
        while token_idx < unique_tokens.len() {
            let current_token_id = *unique_tokens.at(token_idx);

            // Recopilar simulaciones para este token
            let mut token_simulations: Array<felt252> = ArrayTrait::new();

            let mut sim_idx: u32 = 0;
            while sim_idx < simulation_ids.len() {
                let simulation_id = *simulation_ids.at(sim_idx);
                let simulation = self.simulations.entry(simulation_id).read();

                if simulation.creator != zero_address && simulation.token_id == current_token_id {
                    token_simulations.append(simulation_id);
                }

                sim_idx += 1;
            }

            // Usar el método interno para obtener el summary del token
            let token_summary = self
                ._get_wallet_token_summary_internal(
                    current_token_id, wallet, token_simulations.span(),
                );

            tokens_summary.append(token_summary);
            token_idx += 1;
        }

        WalletMultiTokenSummary { wallet, summaries: tokens_summary }
    }

    #[external(v0)]
    fn pay_for_session(
        ref self: ContractState, simulation_id: felt252, session_id: felt252, amount: u256,
    ) {
        let caller = get_caller_address();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        // 1. Verify simulation exists
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 2. Get token_id from simulation
        let token_id = simulation.token_id;

        // 3. Verify caller is whitelisted for this simulation
        let is_whitelisted = self.whitelist.is_whitelisted(token_id, simulation_id, caller);
        assert(is_whitelisted, 'Not whitelisted');

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
            session_id, simulation_id, payer: caller, amount, timestamp: current_time,
        };
        self.paid_sessions.entry(session_id).write(session_payment);

        // 8. Emit event
        self.emit(SessionPaid { session_id, simulation_id, payer: caller, amount, token_id });
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
        ref self: ContractState, simulation_id: felt252, hint_id: felt252, amount: u256,
    ) {
        let caller = get_caller_address();
        let zero_address: ContractAddress = 0.try_into().unwrap();

        // 1. Verify simulation exists
        let simulation = self.simulations.entry(simulation_id).read();
        assert(simulation.creator != zero_address, 'Simulation does not exist');

        // 2. Get token_id from simulation
        let token_id = simulation.token_id;

        // 3. Verify caller is whitelisted for this simulation
        let is_whitelisted = self.whitelist.is_whitelisted(token_id, simulation_id, caller);
        assert(is_whitelisted, 'Not whitelisted');

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
            hint_id, simulation_id, payer: caller, amount, timestamp: current_time,
        };
        self.paid_hints.entry(hint_id).write(hint_payment);

        // 8. Emit event
        self.emit(HintPaid { hint_id, simulation_id, payer: caller, amount, token_id });
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

        fn _assert_only_registry(self: @ContractState) {
            let caller = get_caller_address();
            let registry = self.registry_address.read();
            let zero_address: ContractAddress = 0.try_into().unwrap();

            // Registry must be configured
            assert(registry != zero_address, 'Registry not configured');

            // Verificar que el caller sea el registry
            assert(caller == registry, 'Only registry can call');
        }

        fn calculate_claimable_days(
            self: @ContractState, current_time: u64, start_time: u64, release_hour: u64,
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

        fn _get_wallet_token_summary_internal(
            self: @ContractState,
            token_id: u256,
            wallet: ContractAddress,
            simulation_ids: Span<felt252>,
        ) -> WalletTokenSummary {
            let token_info = self.token_info.entry(token_id).read();
            let current_time = starknet::get_block_timestamp();
            let current_balance = self.erc1155.balance_of(wallet, token_id);

            let mut simulations_data: Array<SimulationClaimData> = ArrayTrait::new();
            let mut total_claimable: u256 = 0;

            // Iterate through all provided simulation_ids
            let mut i: u32 = 0;
            while i < simulation_ids.len() {
                let simulation_id = *simulation_ids.at(i);
                let simulation = self.simulations.entry(simulation_id).read();

                // Check if whitelisted
                let is_whitelisted = self.whitelist.is_whitelisted(token_id, simulation_id, wallet);

                // Check if simulation is expired
                let is_expired = current_time >= simulation.expiration_timestamp;

                // Only include if whitelisted AND not expired
                if is_whitelisted && !is_expired {
                    let last_claim = self
                        .last_claim_timestamp
                        .entry((token_id, simulation_id, wallet))
                        .read();

                    let amount = if last_claim == 0 {
                        // FIRST CLAIM: special_release + normal days
                        let special_amount = token_info.special_release;

                        let normal_days = self
                            .calculate_claimable_days(
                                current_time,
                                simulation.creation_timestamp,
                                token_info.release_hour,
                            );
                        let normal_amount = token_info.release_amount * normal_days;

                        special_amount + normal_amount
                    } else {
                        // Total claimable days until now
                        let total_claimable_days = self
                            .calculate_claimable_days(
                                current_time,
                                simulation.creation_timestamp,
                                token_info.release_hour,
                            );

                        // Days already claimed
                        let days_already_claimed = self
                            .calculate_claimable_days(
                                last_claim, simulation.creation_timestamp, token_info.release_hour,
                            );

                        // Calculate only new days (return 0 if nothing new)
                        if total_claimable_days > days_already_claimed {
                            let new_days = total_claimable_days - days_already_claimed;
                            token_info.release_amount * new_days
                        } else {
                            0
                        }
                    };

                    // Add to results
                    simulations_data
                        .append(SimulationClaimData { simulation_id, claimable_amount: amount });
                    total_claimable += amount;
                }

                i += 1;
            }

            // Compute time until next release for this token
            let seconds_per_day: u64 = 86400;
            let seconds_per_hour: u64 = 3600;
            let seconds_today = current_time % seconds_per_day;
            let release_seconds = token_info.release_hour * seconds_per_hour;
            let time_until = if seconds_today < release_seconds {
                release_seconds - seconds_today
            } else {
                seconds_per_day - seconds_today + release_seconds
            };
            WalletTokenSummary {
                token_id,
                wallet,
                current_balance,
                token_info,
                total_claimable,
                simulations_data,
                time_until_release: time_until,
            }
        }
    }
}
