use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Character metadata for registration
#[derive(Drop, Serde, Copy)]
pub struct CharacterMetadata {
    pub character_id: felt252,
    pub character_hash: felt252,
    pub author: ContractAddress,
}

/// Character Registry Interface
#[starknet::interface]
pub trait ICharacterRegistry<TContractState> {
    /// Register a character with its metadata (only owner)
    fn register_character(ref self: TContractState, metadata: CharacterMetadata);
    /// Verify if a character ID matches its expected hash
    fn verify_character(
        self: @TContractState, character_id: felt252, character_hash: felt252,
    ) -> VerificationResult;
    /// Verify multiple characters at once
    fn batch_verify_characters(
        self: @TContractState, characters: Array<CharacterMetadata>,
    ) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a character ID
    fn get_character_hash(self: @TContractState, character_id: felt252) -> felt252;
    /// Get complete character information
    fn get_character_info(self: @TContractState, character_id: felt252) -> CharacterMetadata;
}

/// Character Registered Event
#[derive(Drop, starknet::Event)]
pub struct CharacterRegistered {
    #[key]
    pub character_id: felt252,
    pub character_hash: felt252,
    pub registered_by: ContractAddress,
}
