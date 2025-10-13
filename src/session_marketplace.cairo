// SPDX-License-Identifier: MIT

use starknet::ContractAddress;
// Re-export interface dispatchers and types from interfaces module at file scope
pub use crate::interfaces::session_marketplace_interface::{
    ISessionMarketplaceDispatcher, ISessionMarketplaceDispatcherTrait, ListingStatus, SessionListing,
};
use crate::interfaces::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait};

// Interface moved to crate::interfaces::session_marketplace

#[starknet::contract]
mod SessionMarketplace {
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::session_registry::ISessionRegistryDispatcherTrait;
    use super::{ListingStatus, SessionListing};

    #[storage]
    struct Storage {
        registry: ContractAddress,
        // Map from session_id to SessionListing
        sessions: Map<felt252, SessionListing>,
        // Map from simulation_id to list of session_ids
        simulation_sessions: Map<felt252, Vec<felt252>>,
        // Track if a session exists
        session_exists: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SessionPublished: SessionPublished,
        SessionPurchased: SessionPurchased,
        SessionCancelled: SessionCancelled,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionPublished {
        #[key]
        session_id: felt252,
        #[key]
        simulation_id: felt252,
        #[key]
        seller: ContractAddress,
        root_hash: felt252,
        price: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionPurchased {
        #[key]
        session_id: felt252,
        #[key]
        seller: ContractAddress,
        #[key]
        buyer: ContractAddress,
        price: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionCancelled {
        #[key]
        session_id: felt252,
        #[key]
        seller: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, registry_address: ContractAddress) {
        assert(!registry_address.is_zero(), 'Invalid registry address');
        self.registry.write(registry_address);
    }

    #[abi(embed_v0)]
    use crate::interfaces::session_marketplace_interface::ISessionMarketplace;
    impl SessionMarketplaceImpl of ISessionMarketplace<ContractState> {
        /// Publish a new session for sale
        fn publish_session(
            ref self: ContractState,
            simulation_id: felt252,
            session_id: felt252,
            price: u128,
        ) {
            let caller = get_caller_address();

            // Verificar que la sesión no exista ya
            assert(!self.session_exists.entry(session_id).read(), 'Session already exists');

            // Verificar que el precio sea mayor a 0
            assert(price > 0, 'Price must be greater than 0');

            // Validar en el registry que la sesión existe y pertenece al caller
            let registry = crate::session_registry::ISessionRegistryDispatcher { contract_address: self.registry.read() };
            let info = registry.get_session_info(session_id);
            assert(info.root_hash != 0, 'Session not found in registry');
            assert(info.author == caller, 'Not session owner');
            // Opcional: validar simulation_id coincide con lo registrado
            assert(info.simulation_id == simulation_id, 'Simulation mismatch');
            let root_hash = info.root_hash;

            // Crear el listing de la sesión
            let zero_address: ContractAddress = 0.try_into().unwrap();
            let listing = SessionListing {
                session_id,
                simulation_id,
                root_hash,
                price,
                seller: caller,
                buyer: zero_address,
                status: ListingStatus::Available,
            };

            // Guardar la sesión
            self.sessions.entry(session_id).write(listing);
            self.session_exists.entry(session_id).write(true);

            // Agregar el session_id a la lista de sesiones de la simulación
            let mut sim_sessions = self.simulation_sessions.entry(simulation_id);
            sim_sessions.push(session_id);

            // Emitir evento
            self
                .emit(
                    SessionPublished {
                        session_id, simulation_id, seller: caller, root_hash, price,
                    },
                );
        }

        /// Purchase a session
        fn purchase_session(ref self: ContractState, session_id: felt252) {
            let caller = get_caller_address();

            // Verificar que la sesión existe
            assert(self.session_exists.entry(session_id).read(), 'Session does not exist');

            // Obtener la sesión
            let mut listing = self.sessions.entry(session_id).read();

            // Verificar que la sesión esté disponible
            assert(listing.status == ListingStatus::Available, 'Session not available');

            // Verificar que el comprador no sea el vendedor
            assert(caller != listing.seller, 'Cannot buy your own session');

            // Actualizar el listing
            listing.buyer = caller;
            listing.status = ListingStatus::Sold;
            self.sessions.entry(session_id).write(listing);

            // Emitir evento
            self
                .emit(
                    SessionPurchased {
                        session_id, seller: listing.seller, buyer: caller, price: listing.price,
                    },
                );
            // TODO: Implementar lógica de transferencia de fondos/tokens
        // Aquí se debería integrar con un contrato ERC20 para transferir el pago
        }

        /// Get all sessions for a given simulation_id
        fn get_sessions_by_simulation(
            self: @ContractState, simulation_id: felt252,
        ) -> Array<SessionListing> {
            let mut result: Array<SessionListing> = ArrayTrait::new();
            let sim_sessions = self.simulation_sessions.entry(simulation_id);
            let len = sim_sessions.len();

            let mut i: u64 = 0;
            while i < len {
                let session_id = sim_sessions.at(i).read();
                let listing = self.sessions.entry(session_id).read();

                // Solo agregar si la sesión existe (no fue removida)
                if self.session_exists.entry(session_id).read() {
                    result.append(listing);
                }

                i += 1;
            }

            result
        }

        /// Remove/cancel a session listing (only by the original seller before it's sold)
        fn remove_session(ref self: ContractState, session_id: felt252) {
            let caller = get_caller_address();

            // Verificar que la sesión existe
            assert(self.session_exists.entry(session_id).read(), 'Session does not exist');

            // Obtener la sesión para verificar el seller
            let mut listing = self.sessions.entry(session_id).read();

            // Verificar que el caller sea el seller
            assert(listing.seller == caller, 'Not the seller');

            // Verificar que la sesión no haya sido vendida
            assert(listing.status == ListingStatus::Available, 'Cannot cancel sold session');

            // Actualizar el estado a cancelado
            listing.status = ListingStatus::Cancelled;
            self.sessions.entry(session_id).write(listing);

            // Marcar como no existente para que no aparezca en las búsquedas
            self.session_exists.entry(session_id).write(false);

            // Emitir evento
            self.emit(SessionCancelled { session_id, seller: caller });
        }

        /// Get a specific session by session_id
        fn get_session(self: @ContractState, session_id: felt252) -> SessionListing {
            assert(self.session_exists.entry(session_id).read(), 'Session does not exist');
            self.sessions.entry(session_id).read()
        }

        /// Check if a session exists
        fn session_exists(self: @ContractState, session_id: felt252) -> bool {
            self.session_exists.entry(session_id).read()
        }

        /// Check if a session is available for purchase
        fn is_available(self: @ContractState, session_id: felt252) -> bool {
            if !self.session_exists.entry(session_id).read() {
                return false;
            }

            let listing = self.sessions.entry(session_id).read();
            listing.status == ListingStatus::Available
        }
    }
}
