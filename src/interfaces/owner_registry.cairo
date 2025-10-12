use starknet::ContractAddress;

#[starknet::interface]
pub trait IOwnerRegistry<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_nft_address(self: @TContractState) -> ContractAddress;
    fn get_tokens_core_address(self: @TContractState) -> ContractAddress;
    fn get_pox_nft_address(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn set_pox_nft_address(ref self: TContractState, pox_nft: ContractAddress);
}

