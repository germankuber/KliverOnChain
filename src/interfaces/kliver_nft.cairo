use starknet::ContractAddress;

/// Interface for Kliver User NFT (Soulbound)
#[starknet::interface]
pub trait IKliverNFT<TContractState> {
    fn mint_to_user(ref self: TContractState, to: ContractAddress);
    fn user_has_nft(self: @TContractState, user: ContractAddress) -> bool;
    fn total_supply(self: @TContractState) -> u256;
    fn get_user_token_id(self: @TContractState, user: ContractAddress) -> u256;
    fn get_minted_at(self: @TContractState, token_id: u256) -> u64;
    fn burn_user_nft(ref self: TContractState, user: ContractAddress);
}

