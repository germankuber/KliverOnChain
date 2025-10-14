use starknet::ContractAddress;

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum ListingStatus {
    Open,
    Closed,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Listing {
    pub session_id: felt252,
    pub root: felt252,
    pub seller: ContractAddress,
    pub buyer: ContractAddress,
    pub status: ListingStatus,
    pub challenge: u64,
    pub price: u256,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum OrderStatus {
    Open,
    Settled,
    Refunded,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Order {
    pub session_id: felt252,
    pub buyer: ContractAddress,
    pub challenge: u64,
    pub amount: u256,
    pub status: OrderStatus,
}

#[starknet::interface]
pub trait IMarketplace<TContractState> {
    // Seller functions
    fn create_listing(ref self: TContractState, token_id: u256, price: u256);
    fn close_listing(ref self: TContractState, token_id: u256);
    
    // Buyer functions
    fn open_purchase(
        ref self: TContractState, token_id: u256, challenge: u64, amount: u256
    );
    fn refund_purchase(ref self: TContractState, token_id: u256);
    fn settle_purchase(
        ref self: TContractState,
        token_id: u256,
        buyer: ContractAddress,
        challenge: u64,
        proof: Span<felt252>,
    );
    
    // View functions - Listing
    fn get_listing(self: @TContractState, token_id: u256) -> Listing;
    fn get_listing_status(self: @TContractState, token_id: u256) -> ListingStatus;
    fn get_listing_count(self: @TContractState) -> u256;
    fn get_pox_address(self: @TContractState) -> ContractAddress;
    fn get_verifier_address(self: @TContractState) -> ContractAddress;
    fn get_payment_token(self: @TContractState) -> ContractAddress;
    fn get_purchase_timeout(self: @TContractState) -> u64;
    fn get_owner(self: @TContractState) -> ContractAddress;
    
    // Admin functions
    fn set_verifier_address(ref self: TContractState, new_verifier: ContractAddress);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    
    // View functions - History
    fn get_token_listing_count(self: @TContractState, token_id: u256) -> u256;
    fn get_listing_id_at_index(self: @TContractState, token_id: u256, index: u256) -> u256;
    fn get_active_listing_id(self: @TContractState, token_id: u256) -> u256;
    fn get_listing_by_id(self: @TContractState, listing_id: u256) -> Listing;
    
    // View functions - Orders
    fn is_order_closed(self: @TContractState, token_id: u256, buyer: ContractAddress) -> bool;
    fn get_order(self: @TContractState, token_id: u256, buyer: ContractAddress) -> Order;
    fn get_order_status(self: @TContractState, token_id: u256, buyer: ContractAddress) -> OrderStatus;
    fn get_order_info(self: @TContractState, token_id: u256, buyer: ContractAddress) -> (u64, u256);
}
