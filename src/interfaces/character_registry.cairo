use kliver_on_chain::components::character_registry_component::CharacterMetadata;
use starknet::ContractAddress;
use crate::types::VerificationResult;

#[starknet::interface]
pub trait ICharacterRegistry<TContractState> {
    fn register_character(ref self: TContractState, metadata: CharacterMetadata);
    fn verify_character(self: @TContractState, character_id: felt252, character_hash: felt252) -> VerificationResult;
    fn batch_verify_characters(self: @TContractState, characters: Array<CharacterMetadata>) -> Array<(felt252, VerificationResult)>;
    fn get_character_hash(self: @TContractState, character_id: felt252) -> felt252;
    fn get_character_info(self: @TContractState, character_id: felt252) -> CharacterMetadata;
}

#[derive(Drop, starknet::Event)]
pub struct CharacterRegistered {
    #[key]
    pub character_id: felt252,
    pub character_hash: felt252,
    pub registered_by: ContractAddress,
}

