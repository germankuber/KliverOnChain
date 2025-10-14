use starknet::ContractAddress;

#[starknet::interface]
pub trait IOwnerRegistry<TContractState> {
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_nft_address(self: @TContractState) -> ContractAddress;
    fn get_tokens_core_address(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    // KliverPox address management
    fn set_kliver_pox_address(ref self: TContractState, addr: ContractAddress);
    fn get_kliver_pox_address(self: @TContractState) -> ContractAddress;
    // Verifier address management
    fn get_verifier_address(self: @TContractState) -> ContractAddress;
    fn set_verifier_address(ref self: TContractState, new_verifier: ContractAddress);
}
