// SPDX-License-Identifier: MIT

use starknet::ContractAddress;
// Re-export interface dispatcher and types
pub use crate::interfaces::session_escrow::{
    ISessionEscrow, ISessionEscrowDispatcher, ISessionEscrowDispatcherTrait, Session,
};

#[starknet::contract]
mod SessionEscrow {
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};
    use super::Session;

    #[storage]
    struct Storage {
        // Map from session_id to Session
        sessions: Map<felt252, Session>,
        // Map from simulation_id to list of session_ids
        simulation_sessions: Map<felt252, Vec<felt252>>,
        // Track if a session exists
        session_exists: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SessionPublished: SessionPublished,
        SessionRemoved: SessionRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionPublished {
        #[key]
        session_id: felt252,
        #[key]
        simulation_id: felt252,
        #[key]
        publisher: ContractAddress,
        root_hash: felt252,
        score: u128,
        price: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionRemoved {
        #[key]
        session_id: felt252,
        #[key]
        publisher: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
    ) { // Constructor vacío, no necesita inicialización especial
    }

    #[abi(embed_v0)]
    use crate::interfaces::session_escrow::ISessionEscrow;
    impl SessionEscrowImpl of ISessionEscrow<ContractState> {
        /// Publish a new session
        fn publish_session(
            ref self: ContractState,
            simulation_id: felt252,
            session_id: felt252,
            root_hash: felt252,
            score: u128,
            price: u128,
        ) {
            let caller = get_caller_address();

            // Verificar que la sesión no exista ya
            assert(!self.session_exists.entry(session_id).read(), 'Session already exists');

            // Crear la sesión
            let session = Session {
                session_id, simulation_id, root_hash, score, price, publisher: caller,
            };

            // Guardar la sesión
            self.sessions.entry(session_id).write(session);
            self.session_exists.entry(session_id).write(true);

            // Agregar el session_id a la lista de sesiones de la simulación
            let mut sim_sessions = self.simulation_sessions.entry(simulation_id);
            sim_sessions.push(session_id);

            // Emitir evento
            self
                .emit(
                    SessionPublished {
                        session_id, simulation_id, publisher: caller, root_hash, score, price,
                    },
                );
        }

        /// Get all sessions for a given simulation_id
        fn get_sessions_by_simulation(
            self: @ContractState, simulation_id: felt252,
        ) -> Array<Session> {
            let mut result: Array<Session> = ArrayTrait::new();
            let sim_sessions = self.simulation_sessions.entry(simulation_id);
            let len = sim_sessions.len();

            let mut i: u64 = 0;
            while i < len {
                let session_id = sim_sessions.at(i).read();
                let session = self.sessions.entry(session_id).read();

                // Solo agregar si la sesión existe (no fue removida)
                if self.session_exists.entry(session_id).read() {
                    result.append(session);
                }

                i += 1;
            }

            result
        }

        /// Remove a session (only by the original publisher)
        fn remove_session(ref self: ContractState, session_id: felt252) {
            let caller = get_caller_address();

            // Verificar que la sesión existe
            assert(self.session_exists.entry(session_id).read(), 'Session does not exist');

            // Obtener la sesión para verificar el publisher
            let session = self.sessions.entry(session_id).read();

            // Verificar que el caller sea el publisher
            assert(session.publisher == caller, 'Not the publisher');

            // Marcar como no existente (soft delete)
            self.session_exists.entry(session_id).write(false);

            // Emitir evento
            self.emit(SessionRemoved { session_id, publisher: caller });
        }

        /// Get a specific session by session_id
        fn get_session(self: @ContractState, session_id: felt252) -> Session {
            assert(self.session_exists.entry(session_id).read(), 'Session does not exist');
            self.sessions.entry(session_id).read()
        }

        /// Check if a session exists
        fn session_exists(self: @ContractState, session_id: felt252) -> bool {
            self.session_exists.entry(session_id).read()
        }
    }
}
