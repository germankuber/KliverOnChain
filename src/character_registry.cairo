use starknet::ContractAddress;

/// Character Registry Interface
#[starknet::interface]
pub trait ICharacterRegistry<TContractState> {
    /// Register a character version with its ID and hash (only owner)
    fn register_character_version(ref self: TContractState, character_version_id: felt252, character_version_hash: felt252);
    /// Verify if a character version ID matches its expected hash
    fn verify_character_version(self: @TContractState, character_version_id: felt252, character_version_hash: felt252) -> bool;
    /// Verify multiple character versions at once
    fn batch_verify_character_versions(self: @TContractState, character_versions: Array<(felt252, felt252)>) -> Array<(felt252, bool)>;
    /// Get the hash for a character version ID
    fn get_character_version_hash(self: @TContractState, character_version_id: felt252) -> felt252;
}

/// Character Version Registered Event
#[derive(Drop, starknet::Event)]
pub struct CharacterVersionRegistered {
    #[key]
    pub character_version_id: felt252,
    pub character_version_hash: felt252,
    pub registered_by: ContractAddress,
}