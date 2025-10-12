use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PoxInfo {
    pub session_id: felt252,
    pub root_hash: felt252,
    pub simulation_id: felt252,
    pub score: u32,
}

#[starknet::interface]
pub trait IPoxNFT<TContractState> {
    // Registry admin
    fn get_registry(self: @TContractState) -> ContractAddress;
    fn set_registry(ref self: TContractState, new_registry: ContractAddress);

    // Linked Kliver NFT contract admin
    fn get_kliver_nft(self: @TContractState) -> ContractAddress;
    fn set_kliver_nft(ref self: TContractState, new_kliver_nft: ContractAddress);

    // Minting (only registry)
    fn mint(
        ref self: TContractState,
        session_id: felt252,
        root_hash: felt252,
        simulation_id: felt252,
        score: u32,
        author: ContractAddress,
    );

    // Convenience getters
    fn user_has_nft(self: @TContractState, user: ContractAddress) -> bool;
    fn get_user_token_id(self: @TContractState, user: ContractAddress) -> u256;
    fn total_supply(self: @TContractState) -> u256;

    // Read info stored for a token
    fn get_pox_info(self: @TContractState, token_id: u256) -> PoxInfo;

    // Mapping helpers
    fn get_token_id_by_session(self: @TContractState, session_id: felt252) -> u256;
}
