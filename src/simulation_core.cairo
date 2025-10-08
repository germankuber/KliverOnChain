// SPDX-License-Identifier: MIT
// SimulationCore.cairo
// Handles whitelist, rewards, and spending logic for Kliver simulations.

use starknet::ContractAddress;

// ────────────────────────────────────────────────
// Shared Structures
// ────────────────────────────────────────────────

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Simulation {
    pub token_id: felt252,
    pub daily_amount: u256,
    pub active: bool,
    pub release_hour: u8,
    pub vesting_start_time: u64,
}

#[derive(Drop, Serde, Copy)]
pub struct ClaimableInfo {
    pub simulation_id: felt252,
    pub claimable_tokens: u256,
    pub days_available: u64,
    pub is_whitelisted: bool,
    pub is_active: bool,
}

#[derive(Drop, Serde, Copy)]
pub struct TimeUntilClaim {
    pub can_claim_now: bool,
    pub seconds_until_next: u64,
    pub next_claim_day: u64,
    pub current_day: u64,
}

// ────────────────────────────────────────────────
// External interfaces
// ────────────────────────────────────────────────

#[starknet::interface]
pub trait IKliverRegistry<TContractState> {
    fn simulation_exists(self: @TContractState, simulation_id: felt252) -> bool;
}

#[starknet::interface]
pub trait IKliver1155<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, id: felt252, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, id: felt252, amount: u256);
    fn balance_of(self: @TContractState, owner: ContractAddress, id: felt252) -> u256;
}

// ────────────────────────────────────────────────
// Contract Interface
// ────────────────────────────────────────────────

#[starknet::interface]
pub trait ISimulationCore<TContractState> {
    fn register_simulation(
        ref self: TContractState, simulation_id: felt252, daily_amount: u256, release_hour: u8,
    );
    fn add_to_whitelist(ref self: TContractState, simulation_id: felt252, wallet: ContractAddress);
    fn remove_from_whitelist(
        ref self: TContractState, simulation_id: felt252, wallet: ContractAddress,
    );
    fn is_whitelisted(
        self: @TContractState, simulation_id: felt252, wallet: ContractAddress,
    ) -> bool;
    fn claim_tokens(ref self: TContractState, simulation_id: felt252);
    fn spend_tokens(ref self: TContractState, simulation_id: felt252, amount: u256);
    fn get_simulation_data(self: @TContractState, simulation_id: felt252) -> Simulation;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn is_simulation_registered(self: @TContractState, simulation_id: felt252) -> bool;
    fn is_simulation_active(self: @TContractState, simulation_id: felt252) -> bool;
    fn activate_simulation(ref self: TContractState, simulation_id: felt252);
    fn deactivate_simulation(ref self: TContractState, simulation_id: felt252);

    fn balance_of(self: @TContractState, simulation_id: felt252, user: ContractAddress) -> u256;
    fn get_claimable_tokens(
        self: @TContractState, simulation_id: felt252, user: ContractAddress,
    ) -> u256;
    fn get_claimable_tokens_batch(
        self: @TContractState, user: ContractAddress, simulation_ids: Array<felt252>,
    ) -> Array<ClaimableInfo>;
    fn get_time_until_next_claim(
        self: @TContractState, simulation_id: felt252, user: ContractAddress,
    ) -> TimeUntilClaim;
    fn get_time_until_next_claim_batch(
        self: @TContractState, user: ContractAddress, simulation_ids: Array<felt252>,
    ) -> Array<TimeUntilClaim>;

    //////////TODO : DELETE /////////////
    fn update_release_hour(ref self: TContractState, simulation_id: felt252, new_release_hour: u8);
    //////////TODO : DELETE /////////////

}

// ────────────────────────────────────────────────
// Contract
// ────────────────────────────────────────────────

#[starknet::contract]
mod SimulationCore {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::{
        IKliver1155Dispatcher, IKliver1155DispatcherTrait, IKliverRegistryDispatcher,
        IKliverRegistryDispatcherTrait,
    };

    const ONE_DAY: u64 = 86400; // seconds in one day

    // ─────────────── Storage
    // ───────────────
    #[storage]
    struct Storage {
        owner: ContractAddress,
        registry_address: ContractAddress,
        token_address: ContractAddress,
        simulations: Map<felt252, super::Simulation>,
        whitelist: Map<(felt252, ContractAddress), bool>,
        last_claim_day: Map<(felt252, ContractAddress), u64>,
        next_token_id: felt252,
    }

    // ─────────────── Events
    // ───────────────
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SimulationRegistered: SimulationRegistered,
        Whitelisted: Whitelisted,
        WhitelistRemoved: WhitelistRemoved,
        TokensClaimed: TokensClaimed,
        TokensSpent: TokensSpent,
        SimulationActivated: SimulationActivated,
        SimulationDeactivated: SimulationDeactivated,
    }

    #[derive(Drop, starknet::Event)]
    struct SimulationRegistered {
        simulation_id: felt252,
        token_id: felt252,
        daily_amount: u256,
        release_hour: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct WhitelistRemoved {
        simulation_id: felt252,
        wallet: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Whitelisted {
        simulation_id: felt252,
        wallet: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensClaimed {
        simulation_id: felt252,
        wallet: ContractAddress,
        amount: u256,
        days_claimed: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensSpent {
        simulation_id: felt252,
        wallet: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct SimulationActivated {
        simulation_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct SimulationDeactivated {
        simulation_id: felt252,
    }

    // ─────────────── Constructor
    // ───────────────
    #[constructor]
    fn constructor(
        ref self: ContractState,
        registry_address: ContractAddress,
        token_address: ContractAddress,
        owner: ContractAddress,
    ) {
        assert(!registry_address.is_zero(), 'Invalid registry');
        assert(!token_address.is_zero(), 'Invalid token');
        assert(!owner.is_zero(), 'Invalid owner');

        self.owner.write(owner);
        self.registry_address.write(registry_address);
        self.token_address.write(token_address);
        self.next_token_id.write(1);
    }

    // ─────────────── Internal helpers
    // ───────────────
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn only_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'Not authorized');
        }

        fn get_current_day(self: @ContractState, simulation_id: felt252) -> u64 {
            let current_time = get_block_timestamp();
            let sim = self.simulations.entry(simulation_id).read();
            let start_time = sim.vesting_start_time;

            if current_time < start_time {
                return 0;
            }

            let elapsed = current_time - start_time;
            let days_passed = elapsed / ONE_DAY;

            days_passed
        }

        fn get_claimable_days(
            self: @ContractState, simulation_id: felt252, user: ContractAddress,
        ) -> u64 {
            let current_day = self.get_current_day(simulation_id);
            let last_claimed_day = self.last_claim_day.entry((simulation_id, user)).read();

            if last_claimed_day == current_day {
                return 0;
            }

            let sim = self.simulations.entry(simulation_id).read();
            let release_hour_seconds = sim.release_hour.into() * 3600;

            let current_time = get_block_timestamp();
            let start_time = sim.vesting_start_time;
            let elapsed = current_time - start_time;
            let seconds_in_current_day = elapsed % ONE_DAY;
            let can_claim_today = seconds_in_current_day >= release_hour_seconds;

            // ✅ CASO ESPECIAL: Día 0
            if current_day == 0 {
                // En día 0, solo puedes claimear si ya pasó la release_hour
                if can_claim_today && last_claimed_day == 0 {
                    return 1; // Puedes claimear 1 día (el día 0)
                } else {
                    return 0;
                }
            }

            // Día 1+: lógica normal
            let days_between = if last_claimed_day == 0 {
                current_day - 1
            } else {
                if current_day <= last_claimed_day {
                    return 0;
                }
                current_day - last_claimed_day - 1
            };

            days_between + (if can_claim_today {
                1
            } else {
                0
            })
        }

        fn can_claim_now_with_user(
            self: @ContractState, simulation_id: felt252, user: ContractAddress,
        ) -> bool {
            let current_time = get_block_timestamp();
            let sim = self.simulations.entry(simulation_id).read();
            let start_time = sim.vesting_start_time;

            if current_time < start_time {
                return false;
            }

            let current_day = self.get_current_day(simulation_id);
            let last_claimed_day = self.last_claim_day.entry((simulation_id, user)).read();

            if last_claimed_day == current_day {
                return false;
            }

            let release_hour_seconds = sim.release_hour.into() * 3600;
            let elapsed = current_time - start_time;
            let seconds_in_current_day = elapsed % ONE_DAY;

            // ✅ CASO ESPECIAL: Día 0 - permitir claim si ya pasó release_hour
            if current_day == 0 {
                return seconds_in_current_day >= release_hour_seconds;
            }

            // Día 1+: lógica normal
            let days_between = if last_claimed_day == 0 {
                current_day - 1
            } else {
                if current_day <= last_claimed_day {
                    return false;
                }
                current_day - last_claimed_day - 1
            };

            let can_claim_today = seconds_in_current_day >= release_hour_seconds;
            let total_days_available = days_between + (if can_claim_today {
                1
            } else {
                0
            });

            total_days_available > 0
        }

        fn get_next_release_timestamp(self: @ContractState, simulation_id: felt252) -> u64 {
            let current_time = get_block_timestamp();
            let sim = self.simulations.entry(simulation_id).read();
            let start_time = sim.vesting_start_time;
            let release_hour_seconds = sim.release_hour.into() * 3600;

            if current_time < start_time {
                // ✅ Antes del vesting: próximo release es en día 0 a la release_hour
                return start_time + release_hour_seconds;
            }

            let elapsed = current_time - start_time;
            let days_passed = elapsed / ONE_DAY;
            let seconds_in_current_day = elapsed % ONE_DAY;

            // ✅ En día 0 o después
            if seconds_in_current_day < release_hour_seconds {
                // Antes de release_hour hoy: próximo release es hoy
                start_time + (days_passed * ONE_DAY) + release_hour_seconds
            } else {
                // Después de release_hour hoy: próximo release es mañana
                start_time + ((days_passed + 1) * ONE_DAY) + release_hour_seconds
            }
        }
    }

    // ─────────────── External Implementation
    // ───────────────
    #[abi(embed_v0)]
    impl SimulationCoreImpl of super::ISimulationCore<ContractState> {
        fn register_simulation(
            ref self: ContractState, simulation_id: felt252, daily_amount: u256, release_hour: u8,
        ) {
            self.only_owner();

            assert(!self.is_simulation_registered(simulation_id), 'Already registered');
            assert(release_hour < 24, 'Invalid release hour');
            assert(daily_amount > 0, 'Daily amount must be > 0');

            let registry = IKliverRegistryDispatcher {
                contract_address: self.registry_address.read(),
            };
            assert(registry.simulation_exists(simulation_id), 'Simulation not found');

            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            let vesting_start_time = get_block_timestamp();

            self
                .simulations
                .entry(simulation_id)
                .write(
                    super::Simulation {
                        token_id, daily_amount, active: true, release_hour, vesting_start_time,
                    },
                );

            self.emit(SimulationRegistered { simulation_id, token_id, daily_amount, release_hour });
        }

        fn add_to_whitelist(
            ref self: ContractState, simulation_id: felt252, wallet: ContractAddress,
        ) {
            self.only_owner();
            assert(!wallet.is_zero(), 'Invalid wallet');
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            self.whitelist.entry((simulation_id, wallet)).write(true);
            self.emit(Whitelisted { simulation_id, wallet });
        }

        fn remove_from_whitelist(
            ref self: ContractState, simulation_id: felt252, wallet: ContractAddress,
        ) {
            self.only_owner();
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            self.whitelist.entry((simulation_id, wallet)).write(false);
            self.emit(WhitelistRemoved { simulation_id, wallet });
        }

        fn is_whitelisted(
            self: @ContractState, simulation_id: felt252, wallet: ContractAddress,
        ) -> bool {
            self.whitelist.entry((simulation_id, wallet)).read()
        }

        fn claim_tokens(ref self: ContractState, simulation_id: felt252) {
            let user = get_caller_address();

            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            assert(self.is_simulation_active(simulation_id), 'Simulation not active');
            assert(self.whitelist.entry((simulation_id, user)).read(), 'Not whitelisted');

            let current_day = self.get_current_day(simulation_id);
            let last_claimed_day = self.last_claim_day.entry((simulation_id, user)).read();
            assert(last_claimed_day != current_day, 'Already claimed today');

            assert(self.can_claim_now_with_user(simulation_id, user), 'Claim time not reached');

            let days_to_claim = self.get_claimable_days(simulation_id, user);
            assert(days_to_claim > 0, 'No tokens available to claim');

            let sim = self.simulations.entry(simulation_id).read();
            let tokens_to_mint = sim.daily_amount * days_to_claim.into();

            // EFFECT: Actualizar state ANTES de external call
            self.last_claim_day.entry((simulation_id, user)).write(current_day);

            // INTERACTION: External call DESPUÉS
            let token = IKliver1155Dispatcher { contract_address: self.token_address.read() };
            token.mint(user, sim.token_id, tokens_to_mint);

            self
                .emit(
                    TokensClaimed {
                        simulation_id,
                        wallet: user,
                        amount: tokens_to_mint,
                        days_claimed: days_to_claim,
                    },
                );
        }

        fn spend_tokens(ref self: ContractState, simulation_id: felt252, amount: u256) {
            let user = get_caller_address();

            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            assert(self.is_simulation_active(simulation_id), 'Simulation not active');

            let sim = self.simulations.entry(simulation_id).read();

            let token = IKliver1155Dispatcher { contract_address: self.token_address.read() };
            let balance = token.balance_of(user, sim.token_id);
            assert(balance >= amount, 'Insufficient balance');

            token.burn(user, sim.token_id, amount);
            self.emit(TokensSpent { simulation_id, wallet: user, amount });
        }

        fn get_simulation_data(self: @ContractState, simulation_id: felt252) -> super::Simulation {
            self.simulations.entry(simulation_id).read()
        }

        fn is_simulation_registered(self: @ContractState, simulation_id: felt252) -> bool {
            let sim = self.simulations.entry(simulation_id).read();
            sim.token_id != 0
        }

        fn is_simulation_active(self: @ContractState, simulation_id: felt252) -> bool {
            let sim = self.simulations.entry(simulation_id).read();
            sim.token_id != 0 && sim.active
        }

        fn activate_simulation(ref self: ContractState, simulation_id: felt252) {
            self.only_owner();
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');

            let sim = self.simulations.entry(simulation_id).read();
            let updated_sim = super::Simulation {
                token_id: sim.token_id,
                daily_amount: sim.daily_amount,
                active: true,
                release_hour: sim.release_hour,
                vesting_start_time: sim.vesting_start_time,
            };
            self.simulations.entry(simulation_id).write(updated_sim);
            self.emit(SimulationActivated { simulation_id });
        }

        fn deactivate_simulation(ref self: ContractState, simulation_id: felt252) {
            self.only_owner();
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');

            let sim = self.simulations.entry(simulation_id).read();
            let updated_sim = super::Simulation {
                token_id: sim.token_id,
                daily_amount: sim.daily_amount,
                active: false,
                release_hour: sim.release_hour,
                vesting_start_time: sim.vesting_start_time,
            };
            self.simulations.entry(simulation_id).write(updated_sim);
            self.emit(SimulationDeactivated { simulation_id });
        }

        fn update_release_hour(
            ref self: ContractState, simulation_id: felt252, new_release_hour: u8,
        ) {
            self.only_owner();
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            assert(new_release_hour < 24, 'Invalid release hour');

            let sim = self.simulations.entry(simulation_id).read();
            let updated_sim = super::Simulation {
                token_id: sim.token_id,
                daily_amount: sim.daily_amount,
                active: sim.active,
                release_hour: new_release_hour,
                vesting_start_time: sim.vesting_start_time,
            };
            self.simulations.entry(simulation_id).write(updated_sim);
        }

        fn balance_of(self: @ContractState, simulation_id: felt252, user: ContractAddress) -> u256 {
            let sim_data = self.simulations.entry(simulation_id).read();
            let token = IKliver1155Dispatcher { contract_address: self.token_address.read() };
            token.balance_of(user, sim_data.token_id)
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_claimable_tokens(
            self: @ContractState, simulation_id: felt252, user: ContractAddress,
        ) -> u256 {
            if !self.is_simulation_active(simulation_id) {
                return 0;
            }

            if !self.whitelist.entry((simulation_id, user)).read() {
                return 0;
            }

            let days_available = self.get_claimable_days(simulation_id, user);
            if days_available == 0 {
                return 0;
            }

            let sim = self.simulations.entry(simulation_id).read();
            sim.daily_amount * days_available.into()
        }

        fn get_time_until_next_claim(
            self: @ContractState, simulation_id: felt252, user: ContractAddress,
        ) -> super::TimeUntilClaim {
            let current_day = self.get_current_day(simulation_id);
            let claimable_days = self.get_claimable_days(simulation_id, user);
            let can_claim_now = self.can_claim_now_with_user(simulation_id, user);

            if claimable_days > 0 && can_claim_now {
                return super::TimeUntilClaim {
                    can_claim_now: true,
                    seconds_until_next: 0,
                    next_claim_day: current_day,
                    current_day: current_day,
                };
            }

            let next_release_time = self.get_next_release_timestamp(simulation_id);
            let current_time = get_block_timestamp();
            let sim = self.simulations.entry(simulation_id).read();
            let start_time = sim.vesting_start_time;

            let seconds_until = if next_release_time > current_time {
                next_release_time - current_time
            } else {
                0
            };

            let next_day = if next_release_time >= start_time {
                (next_release_time - start_time) / ONE_DAY
            } else {
                0
            };

            super::TimeUntilClaim {
                can_claim_now: false,
                seconds_until_next: seconds_until,
                next_claim_day: next_day,
                current_day: current_day,
            }
        }

        fn get_time_until_next_claim_batch(
            self: @ContractState, user: ContractAddress, simulation_ids: Array<felt252>,
        ) -> Array<super::TimeUntilClaim> {
            let mut results: Array<super::TimeUntilClaim> = ArrayTrait::new();
            let mut i: u32 = 0;

            while i < simulation_ids.len() {
                let simulation_id = *simulation_ids.at(i);
                let time_until_claim = self.get_time_until_next_claim(simulation_id, user);
                results.append(time_until_claim);
                i += 1;
            }

            results
        }

        fn get_claimable_tokens_batch(
            self: @ContractState, user: ContractAddress, simulation_ids: Array<felt252>,
        ) -> Array<super::ClaimableInfo> {
            let mut results: Array<super::ClaimableInfo> = ArrayTrait::new();
            let mut i: u32 = 0;

            while i < simulation_ids.len() {
                let simulation_id = *simulation_ids.at(i);

                let is_registered = self.is_simulation_registered(simulation_id);
                let is_active = if is_registered {
                    self.is_simulation_active(simulation_id)
                } else {
                    false
                };

                let is_whitelisted = self.whitelist.entry((simulation_id, user)).read();

                let days_available = if is_active && is_whitelisted {
                    self.get_claimable_days(simulation_id, user)
                } else {
                    0
                };

                let claimable_tokens = if days_available > 0 {
                    let sim = self.simulations.entry(simulation_id).read();
                    sim.daily_amount * days_available.into()
                } else {
                    0
                };

                results
                    .append(
                        super::ClaimableInfo {
                            simulation_id,
                            claimable_tokens,
                            days_available,
                            is_whitelisted,
                            is_active,
                        },
                    );

                i += 1;
            }

            results
        }
    }
}
