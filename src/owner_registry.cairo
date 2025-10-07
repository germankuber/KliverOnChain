use starknet::ContractAddress;

/// Owner Registry Interface
#[starknet::interface]
pub trait IOwnerRegistry<TContractState> {
    /// Get the owner of the contract
    fn get_owner(self: @TContractState) -> ContractAddress;
    /// Get the NFT contract address
    fn get_nft_address(self: @TContractState) -> ContractAddress;
    /// Transfer ownership to a new address (only current owner)
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    /// Pause the contract (only owner)
    fn pause(ref self: TContractState);
    /// Unpause the contract (only owner)
    fn unpause(ref self: TContractState);
    /// Check if the contract is paused
    fn is_paused(self: @TContractState) -> bool;
}