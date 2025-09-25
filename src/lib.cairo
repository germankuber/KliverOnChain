use starknet::ContractAddress;

/// Structure for user statistics
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct UserStats {
    pub total_interactions: u32,
    pub total_completed_steps: u32,
    pub total_score: u64,
    pub last_activity: u64,
}

/// Error codes
mod Errors {
    const STEP_COMPLETED: felt252 = 'STEP_ALREADY_COMPLETED';
    const INVALID_POSITION: felt252 = 'INVALID_INTERACTION_POS';
    const PAUSED: felt252 = 'CONTRACT_PAUSED';
    const NOT_OWNER: felt252 = 'NOT_OWNER';
    const ZERO_ADDRESS: felt252 = 'ZERO_ADDRESS';
    const INVALID_SCORE: felt252 = 'INVALID_SCORE';
    const NO_INTERACTIONS: felt252 = 'NO_INTERACTIONS_FOUND';
    const INVALID_PAGINATION: felt252 = 'INVALID_PAGINATION';
}

/// Constants
mod Constants {
    const MAX_INTERACTIONS_PER_STEP: u32 = 15;
    const MAX_SCORE: u32 = 10000;
    const MIN_SCORE: u32 = 0;
    const MAX_PAGINATION_LIMIT: u32 = 100;
}

/// Structure representing an individual AI interaction
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Interaction {
    pub message_hash: felt252,    // Hash of the message
    pub scoring: u32,             // Score of this interaction
    pub timestamp: u64,           // Timestamp of the interaction
}

/// Structure representing a completed step for marketplace
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct CompletedStep {
    pub interactions_hash: felt252,  // Combined hash of all interactions
    pub max_score: u32,             // Highest score in the step
    pub total_interactions: u32,    // Total number of interactions
    pub player: ContractAddress,    // Who completed the step
    pub timestamp: u64,             // When it was completed
}

/// Interface for Kliver Sessions Registry
#[starknet::interface]
pub trait IKliverSessionsRegistry<TContractState> {
    /// Register a new AI interaction
    fn register_interaction(
        ref self: TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252,
        interaction_pos: u32,
        message_hash: felt252,
        scoring: u32
    ) -> bool;

    /// Complete a step and generate marketplace hash
    fn complete_step(
        ref self: TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252
    ) -> felt252;

    /// Get all interactions for a specific step
    fn get_step_interactions(
        self: @TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252
    ) -> Array<Interaction>;

    /// Get completed step information (for marketplace)
    fn get_completed_step(
        self: @TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252
    ) -> CompletedStep;

    /// Get interaction count for a step
    fn get_step_interaction_count(
        self: @TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252
    ) -> u32;

    /// Check if a step is completed
    fn is_step_completed(
        self: @TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252
    ) -> bool;

    /// Get paginated interactions for a step
    fn get_step_interactions_paginated(
        self: @TContractState,
        user_id: felt252,
        challenge_id: felt252,
        session_id: felt252,
        step_id: felt252,
        start: u32,
        limit: u32
    ) -> Array<Interaction>;

    /// Get user statistics
    fn get_user_stats(
        self: @TContractState,
        user_id: felt252
    ) -> UserStats;

    /// Get total contract statistics
    fn get_total_stats(self: @TContractState) -> (u64, u64); // (total_interactions, total_completed_steps)

    /// Admin functions (only owner)
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);

    /// View functions
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn is_paused(self: @TContractState) -> bool;
}

/// Kliver Sessions Registry Contract
#[starknet::contract]
mod KliverSessionsRegistry {
    use super::{Interaction, CompletedStep, IKliverSessionsRegistry, UserStats};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
    use core::poseidon::poseidon_hash_span;
    use core::array::ArrayTrait;
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        /// Individual interactions: (user_id, challenge_id, session_id, step_id, interaction_pos) -> Interaction
        interactions: Map<(felt252, felt252, felt252, felt252, u32), Interaction>,
        
        /// Interaction counts per step: (user_id, challenge_id, session_id, step_id) -> count
        step_interaction_counts: Map<(felt252, felt252, felt252, felt252), u32>,
        
        /// Completed steps for marketplace: (user_id, challenge_id, session_id, step_id) -> CompletedStep
        completed_steps: Map<(felt252, felt252, felt252, felt252), CompletedStep>,
        
        /// Step completion status: (user_id, challenge_id, session_id, step_id) -> bool
        step_completed: Map<(felt252, felt252, felt252, felt252), bool>,

        /// Admin and security
        owner: ContractAddress,
        is_paused: bool,
        reentrancy_guard: bool,
        
        /// Statistics
        user_stats: Map<felt252, UserStats>,
        total_interactions: u64,
        total_completed_steps: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        InteractionRegistered: InteractionRegistered,
        StepCompleted: StepCompleted,
        ContractPaused: ContractPaused,
        ContractUnpaused: ContractUnpaused,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct InteractionRegistered {
        #[key]
        user_id: felt252,
        #[key]
        challenge_id: felt252,
        #[key]
        session_id: felt252,
        #[key]
        step_id: felt252,
        interaction_pos: u32,
        message_hash: felt252,
        scoring: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct StepCompleted {
        #[key]
        user_id: felt252,
        #[key]
        challenge_id: felt252,
        #[key]
        session_id: felt252,
        #[key]
        step_id: felt252,
        interactions_hash: felt252,
        max_score: u32,
        total_interactions: u32,
        player: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractPaused {
        #[key]
        by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUnpaused {
        #[key]
        by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        #[key]
        previous_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        assert(!owner.is_zero(), 'Owner cannot be zero');
        self.owner.write(owner);
        self.is_paused.write(false);
        self.reentrancy_guard.write(false);
        self.total_interactions.write(0);
        self.total_completed_steps.write(0);
    }

    #[abi(embed_v0)]
    impl KliverSessionsRegistryImpl of IKliverSessionsRegistry<ContractState> {
        
        fn register_interaction(
            ref self: ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252,
            interaction_pos: u32,
            message_hash: felt252,
            scoring: u32
        ) -> bool {
            // Security checks
            self._assert_not_paused();
            
            // Validations
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');
            assert(message_hash != 0, 'Message hash cannot be zero');
            assert(interaction_pos > 0, 'Position must be > 0');
            assert(scoring <= 10000, 'Score too high');

            // Verify that the step is not completed
            let step_key = (user_id, challenge_id, session_id, step_id);
            assert(!self.step_completed.read(step_key), 'Step already completed');

            // Verify that the position is the next expected one
            let current_count = self.step_interaction_counts.read(step_key);
            assert(interaction_pos == current_count + 1, 'Invalid interaction position');
            
            // Verify max interactions limit
            assert(current_count < 15, 'Max interactions exceeded');

            // Create the interaction
            let timestamp = get_block_timestamp();
            let interaction = Interaction {
                message_hash,
                scoring,
                timestamp,
            };

            // Guardar la interacción
            let interaction_key = (user_id, challenge_id, session_id, step_id, interaction_pos);
            self.interactions.write(interaction_key, interaction);

            // Actualizar contador
            self.step_interaction_counts.write(step_key, interaction_pos);

            // Update statistics
            self._update_user_stats(user_id, scoring);
            let total = self.total_interactions.read();
            self.total_interactions.write(total + 1);

            // Emit event
            self.emit(InteractionRegistered {
                user_id,
                challenge_id,
                session_id,
                step_id,
                interaction_pos,
                message_hash,
                scoring,
                timestamp,
            });

            true
        }

        fn complete_step(
            ref self: ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252
        ) -> felt252 {
            // Security checks
            self._assert_not_paused();
            
            // Validations
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');

            let step_key = (user_id, challenge_id, session_id, step_id);
            
            // Verificar que el step no esté ya completado
            assert(!self.step_completed.read(step_key), 'Step already completed');

            // Obtener el número de interacciones
            let total_interactions = self.step_interaction_counts.read(step_key);
            assert(total_interactions > 0, 'No interactions found');

            // Recopilar todas las interacciones y calcular el hash
            let mut hash_data: Array<felt252> = ArrayTrait::new();
            let mut max_score: u32 = 0;

            let mut i: u32 = 1;
            while i != total_interactions + 1 {
                let interaction_key = (user_id, challenge_id, session_id, step_id, i);
                let interaction = self.interactions.read(interaction_key);
                
                // Add data to hash
                hash_data.append(interaction.message_hash);
                hash_data.append(interaction.scoring.into());
                
                // Update max_score
                if interaction.scoring > max_score {
                    max_score = interaction.scoring;
                }
                
                i += 1;
            };

            // Calculate combined hash using Poseidon
            let interactions_hash = poseidon_hash_span(hash_data.span());

            // Create CompletedStep
            let timestamp = get_block_timestamp();
            let caller = get_caller_address();
            let completed_step = CompletedStep {
                interactions_hash,
                max_score,
                total_interactions,
                player: caller,
                timestamp,
            };

            // Save completed step
            self.completed_steps.write(step_key, completed_step);
            self.step_completed.write(step_key, true);

            // Update statistics
            self._increment_user_completed_steps(user_id);
            let total_steps = self.total_completed_steps.read();
            self.total_completed_steps.write(total_steps + 1);

            // Emitir evento
            self.emit(StepCompleted {
                user_id,
                challenge_id,
                session_id,
                step_id,
                interactions_hash,
                max_score,
                total_interactions,
                player: caller,
                timestamp,
            });

            interactions_hash
        }

        fn get_step_interactions(
            self: @ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252
        ) -> Array<Interaction> {
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');

            let step_key = (user_id, challenge_id, session_id, step_id);
            let count = self.step_interaction_counts.read(step_key);
            
            let mut interactions: Array<Interaction> = ArrayTrait::new();
            
            let mut i: u32 = 1;
            while i != count + 1 {
                let interaction_key = (user_id, challenge_id, session_id, step_id, i);
                let interaction = self.interactions.read(interaction_key);
                interactions.append(interaction);
                i += 1;
            };

            interactions
        }

        fn get_completed_step(
            self: @ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252
        ) -> CompletedStep {
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');

            let step_key = (user_id, challenge_id, session_id, step_id);
            assert(self.step_completed.read(step_key), 'Step not completed');

            self.completed_steps.read(step_key)
        }

        fn get_step_interaction_count(
            self: @ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252
        ) -> u32 {
            // Validaciones
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');

            let step_key = (user_id, challenge_id, session_id, step_id);
            self.step_interaction_counts.read(step_key)
        }

        fn is_step_completed(
            self: @ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252
        ) -> bool {
            // Validaciones
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');

            let step_key = (user_id, challenge_id, session_id, step_id);
            self.step_completed.read(step_key)
        }

        fn get_step_interactions_paginated(
            self: @ContractState,
            user_id: felt252,
            challenge_id: felt252,
            session_id: felt252,
            step_id: felt252,
            start: u32,
            limit: u32
        ) -> Array<Interaction> {
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');
            assert(limit > 0 && limit <= 100, 'Invalid pagination');

            let step_key = (user_id, challenge_id, session_id, step_id);
            let total_count = self.step_interaction_counts.read(step_key);
            
            assert(start < total_count, 'Invalid pagination');

            let mut interactions: Array<Interaction> = ArrayTrait::new();
            let end = if start + limit > total_count { total_count } else { start + limit };
            
            let mut i = start + 1; // +1 because interactions are 1-indexed
            while i != end + 1 {
                let interaction_key = (user_id, challenge_id, session_id, step_id, i);
                let interaction = self.interactions.read(interaction_key);
                interactions.append(interaction);
                i += 1;
            };

            interactions
        }

        fn get_user_stats(
            self: @ContractState,
            user_id: felt252
        ) -> UserStats {
            assert(user_id != 0, 'User ID cannot be zero');
            self.user_stats.read(user_id)
        }

        fn get_total_stats(self: @ContractState) -> (u64, u64) {
            (self.total_interactions.read(), self.total_completed_steps.read())
        }

        fn pause(ref self: ContractState) {
            self._assert_only_owner();
            assert(!self.is_paused.read(), 'Contract already paused');
            
            self.is_paused.write(true);
            
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            
            self.emit(ContractPaused {
                by: caller,
                timestamp,
            });
        }

        fn unpause(ref self: ContractState) {
            self._assert_only_owner();
            assert(self.is_paused.read(), 'Contract not paused');
            
            self.is_paused.write(false);
            
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            
            self.emit(ContractUnpaused {
                by: caller,
                timestamp,
            });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self._assert_only_owner();
            assert(!new_owner.is_zero(), 'Zero address');
            
            let previous_owner = self.owner.read();
            self.owner.write(new_owner);
            
            let timestamp = get_block_timestamp();
            
            self.emit(OwnershipTransferred {
                previous_owner,
                new_owner,
                timestamp,
            });
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn is_paused(self: @ContractState) -> bool {
            self.is_paused.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Not owner');
        }

        fn _assert_not_paused(self: @ContractState) {
            assert(!self.is_paused.read(), 'Contract paused');
        }

        fn _update_user_stats(ref self: ContractState, user_id: felt252, scoring: u32) {
            let mut stats = self.user_stats.read(user_id);
            stats.total_interactions += 1;
            stats.total_score += scoring.into();
            stats.last_activity = get_block_timestamp();
            self.user_stats.write(user_id, stats);
        }

        fn _increment_user_completed_steps(ref self: ContractState, user_id: felt252) {
            let mut stats = self.user_stats.read(user_id);
            stats.total_completed_steps += 1;
            stats.last_activity = get_block_timestamp();
            self.user_stats.write(user_id, stats);
        }
    }
}