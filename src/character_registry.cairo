use starknet::ContractAddress;
use crate::types::VerificationResult;

/// Character metadata for registration
#[derive(Drop, Serde, Copy)]
pub struct CharacterMetadata {
    pub character_version_id: felt252,
    pub character_version_hash: felt252,
    pub author: ContractAddress,
}

/// Character Registry Interface
#[starknet::interface]
pub trait ICharacterRegistry<TContractState> {
    /// Register a character version with its metadata (only owner)
    fn register_character_version(ref self: TContractState, metadata: CharacterMetadata);
    /// Verify if a character version ID matches its expected hash
    fn verify_character_version(self: @TContractState, character_version_id: felt252, character_version_hash: felt252) -> VerificationResult;
    /// Verify multiple character versions at once
    fn batch_verify_character_versions(self: @TContractState, character_versions: Array<CharacterMetadata>) -> Array<(felt252, VerificationResult)>;
    /// Get the hash for a character version ID
    fn get_character_version_hash(self: @TContractState, character_version_id: felt252) -> felt252;
    /// Get complete character version information
    fn get_character_version_info(self: @TContractState, character_version_id: felt252) -> CharacterMetadata;
}

/// Character Version Registered Event
#[derive(Drop, starknet::Event)]
pub struct CharacterVersionRegistered {
    #[key]
    pub character_version_id: felt252,
    pub character_version_hash: felt252,
    pub registered_by: ContractAddress,
}