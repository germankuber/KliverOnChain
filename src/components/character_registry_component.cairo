use starknet::ContractAddress;

#[derive(Drop, Serde, Copy)]
pub struct CharacterMetadata {
    pub character_id: felt252,
    pub character_hash: felt252,
    pub author: ContractAddress,
}

#[starknet::component]
pub mod CharacterRegistryComponent {
    use kliver_on_chain::types::VerificationResult;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use super::CharacterMetadata;

    #[storage]
    pub struct Storage {
        /// Maps character ID to its hash
        pub characters: Map<felt252, felt252>,
        /// Maps character ID to its author
        pub character_authors: Map<felt252, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CharacterRegistered: CharacterRegistered,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CharacterRegistered {
        #[key]
        pub character_id: felt252,
        pub character_hash: felt252,
        pub registered_by: ContractAddress,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Register a character with its ID, hash and author
        /// This is the core storage operation without business logic validations
        fn register_character(
            ref self: ComponentState<TContractState>,
            character_id: felt252,
            character_hash: felt252,
            author: ContractAddress,
            registered_by: ContractAddress,
        ) {
            // Store character hash and author
            self.characters.entry(character_id).write(character_hash);
            self.character_authors.entry(character_id).write(author);

            // Emit event
            self.emit(CharacterRegistered { character_id, character_hash, registered_by });
        }

        /// Verify if a character ID matches its expected hash
        fn verify_character(
            self: @ComponentState<TContractState>, character_id: felt252, character_hash: felt252,
        ) -> VerificationResult {
            // Get the stored hash for this character ID
            let stored_hash = self.characters.entry(character_id).read();

            // Determine verification result based on stored data
            if stored_hash == 0 {
                VerificationResult::NotFound // ID doesn't exist
            } else if stored_hash == character_hash {
                VerificationResult::Match // ID exists and hash matches
            } else {
                VerificationResult::Mismatch // ID exists but hash doesn't match
            }
        }

        /// Verify multiple characters at once
        fn verify_characters(
            self: @ComponentState<TContractState>,
            characters: Array<kliver_on_chain::types::CharacterVerificationRequest>,
        ) -> Array<kliver_on_chain::types::CharacterVerificationResult> {
            let mut results: Array<kliver_on_chain::types::CharacterVerificationResult> =
                ArrayTrait::new();
            let mut i = 0;
            let len = characters.len();

            while i != len {
                let request = *characters.at(i);
                let character_id = request.character_id;
                let character_hash = request.character_hash;

                // Call verify_character to reuse the verification logic
                let verification_result = self.verify_character(character_id, character_hash);

                results
                    .append(
                        kliver_on_chain::types::CharacterVerificationResult {
                            character_id, result: verification_result,
                        },
                    );
                i += 1;
            }

            results
        }

        /// Get the hash for a character ID
        fn get_character_hash(
            self: @ComponentState<TContractState>, character_id: felt252,
        ) -> felt252 {
            self.characters.entry(character_id).read()
        }

        /// Get complete character information
        fn get_character_info(
            self: @ComponentState<TContractState>, character_id: felt252,
        ) -> CharacterMetadata {
            let character_hash = self.characters.entry(character_id).read();
            let author = self.character_authors.entry(character_id).read();

            CharacterMetadata { character_id, character_hash, author }
        }

        /// Check if a character exists
        fn character_exists(self: @ComponentState<TContractState>, character_id: felt252) -> bool {
            self.characters.entry(character_id).read() != 0
        }
    }
}
