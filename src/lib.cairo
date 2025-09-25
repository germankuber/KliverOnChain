use starknet::ContractAddress;

/// Structure representing an individual AI interaction
#[derive(Drop, Serde, starknet::Store)]
struct Interaction {
    message_hash: felt252,    // Hash of the message
    scoring: u32,             // Score of this interaction
    timestamp: u64,           // Timestamp of the interaction
}

/// Structure representing a completed step for marketplace
#[derive(Drop, Serde, starknet::Store)]
struct CompletedStep {
    interactions_hash: felt252,  // Combined hash of all interactions
    max_score: u32,             // Highest score in the step
    total_interactions: u32,    // Total number of interactions
    player: ContractAddress,    // Who completed the step
    timestamp: u64,             // When it was completed
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
}

/// Kliver Sessions Registry Contract
#[starknet::contract]
mod KliverSessionsRegistry {
    use super::{Interaction, CompletedStep, IKliverSessionsRegistry};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{get_block_timestamp, get_caller_address, ContractAddress};
    use core::poseidon::poseidon_hash_span;

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
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        InteractionRegistered: InteractionRegistered,
        StepCompleted: StepCompleted,
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
            // Validations
            assert(user_id != 0, 'User ID cannot be zero');
            assert(challenge_id != 0, 'Challenge ID cannot be zero');
            assert(session_id != 0, 'Session ID cannot be zero');
            assert(step_id != 0, 'Step ID cannot be zero');
            assert(message_hash != 0, 'Message hash cannot be zero');
            assert(interaction_pos > 0, 'Position must be > 0');

            // Verify that the step is not completed
            let step_key = (user_id, challenge_id, session_id, step_id);
            assert(!self.step_completed.read(step_key), 'Step already completed');

            // Verify that the position is the next expected one
            let current_count = self.step_interaction_counts.read(step_key);
            assert(interaction_pos == current_count + 1, 'Invalid interaction position');

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
    }
}