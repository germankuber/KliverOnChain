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
    fn register_simulation(ref self: TContractState, simulation_id: felt252, daily_amount: u256);
    fn add_to_whitelist(ref self: TContractState, simulation_id: felt252, wallet: ContractAddress);
    fn is_whitelisted(self: @TContractState, simulation_id: felt252, wallet: ContractAddress) -> bool;
    fn claim_tokens(ref self: TContractState, simulation_id: felt252);
    fn spend_tokens(ref self: TContractState, simulation_id: felt252, amount: u256);
    fn get_simulation_data(self: @TContractState, simulation_id: felt252) -> Simulation;
    fn get_owner(self: @TContractState) -> ContractAddress;
    // New methods for simulation management
    fn is_simulation_registered(self: @TContractState, simulation_id: felt252) -> bool;
    fn is_simulation_active(self: @TContractState, simulation_id: felt252) -> bool;
    fn activate_simulation(ref self: TContractState, simulation_id: felt252);
    fn deactivate_simulation(ref self: TContractState, simulation_id: felt252);
    fn balance_of(self: @TContractState, simulation_id: felt252, user: ContractAddress) -> u256;
}

// ────────────────────────────────────────────────
// Contract
// ────────────────────────────────────────────────

#[starknet::contract]
mod SimulationCore {
    use super::{IKliverRegistryDispatcher, IKliverRegistryDispatcherTrait};
    use super::{IKliver1155Dispatcher, IKliver1155DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess};

    const ONE_DAY: u64 = 86400_u64;

    // ─────────────── Storage ───────────────
    #[storage]
    struct Storage {
        owner: ContractAddress,
        registry_address: ContractAddress,
        token_address: ContractAddress,
        simulations: Map<felt252, super::Simulation>,
        whitelist: Map<(felt252, ContractAddress), bool>,
        last_claim: Map<(felt252, ContractAddress), u64>,
        next_token_id: felt252,
    }

    // ─────────────── Events ───────────────
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SimulationRegistered: SimulationRegistered,
        Whitelisted: Whitelisted,
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

    // ─────────────── Constructor ───────────────
    #[constructor]
    fn constructor(
        ref self: ContractState,
        registry_address: ContractAddress,
        token_address: ContractAddress,
        owner: ContractAddress,
    ) {
        self.owner.write(owner);
        self.registry_address.write(registry_address);
        self.token_address.write(token_address);
        self.next_token_id.write(1); // Start token IDs from 1
    }

    // ─────────────── Internal helpers ───────────────
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn only_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'Not authorized');
        }
    }

    // ─────────────── External Implementation ───────────────
    #[abi(embed_v0)]
    impl SimulationCoreImpl of super::ISimulationCore<ContractState> {
        fn register_simulation(ref self: ContractState, simulation_id: felt252, daily_amount: u256) {
            self.only_owner();

            // Verify simulation exists in registry
            let registry = IKliverRegistryDispatcher {
                contract_address: self.registry_address.read(),
            };
            assert(registry.simulation_exists(simulation_id), 'Simulation not found');

            // Get next token ID and increment counter
            let token_id = self.next_token_id.read();
            self.next_token_id.write(token_id + 1);

            self.simulations.entry(simulation_id).write(
                super::Simulation { token_id, daily_amount, active: true }
            );

            self.emit(SimulationRegistered { simulation_id, token_id, daily_amount });
        }

        fn add_to_whitelist(ref self: ContractState, simulation_id: felt252, wallet: ContractAddress) {
            self.only_owner();
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            self.whitelist.entry((simulation_id, wallet)).write(true);
            self.emit(Whitelisted { simulation_id, wallet });
        }

        fn is_whitelisted(self: @ContractState, simulation_id: felt252, wallet: ContractAddress) -> bool {
            self.whitelist.entry((simulation_id, wallet)).read()
        }

        fn claim_tokens(ref self: ContractState, simulation_id: felt252) {
            let user = get_caller_address();
            let now = get_block_timestamp();

            // Validate simulation is registered first, then check if active
            assert(self.is_simulation_registered(simulation_id), 'Simulation not registered');
            assert(self.is_simulation_active(simulation_id), 'Simulation not active');

            // Validate whitelist
            assert(self.whitelist.entry((simulation_id, user)).read(), 'Not whitelisted');

            let sim = self.simulations.entry(simulation_id).read();

            // Cooldown
            let last = self.last_claim.entry((simulation_id, user)).read();
            assert(now >= last + ONE_DAY, 'Claim cooldown not passed');

            // Mint tokens to user
            let token = IKliver1155Dispatcher { contract_address: self.token_address.read() };
            token.mint(user, sim.token_id, sim.daily_amount);

            self.last_claim.entry((simulation_id, user)).write(now);
            self.emit(TokensClaimed { simulation_id, wallet: user, amount: sim.daily_amount });
        }

        fn spend_tokens(ref self: ContractState, simulation_id: felt252, amount: u256) {
            let user = get_caller_address();
            
            // Validate simulation is registered first, then check if active
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

        // New methods for simulation management
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
                active: true
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
                active: false
            };
            self.simulations.entry(simulation_id).write(updated_sim);
            self.emit(SimulationDeactivated { simulation_id });
        }

        fn balance_of(self: @ContractState, simulation_id: felt252, user: ContractAddress) -> u256 {
            // Get the simulation data to obtain the token_id
            let sim_data = self.simulations.entry(simulation_id).read();
            
            // Get the token contract
            let token = IKliver1155Dispatcher { contract_address: self.token_address.read() };
            
            // Call balance_of on the token contract with the token_id
            token.balance_of(user, sim_data.token_id)
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }
}