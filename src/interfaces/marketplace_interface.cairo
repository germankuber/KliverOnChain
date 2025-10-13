use starknet::ContractAddress;

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum ListingStatus {
    Open,
    Purchased,
    Sold,
    Cancelled,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Listing {
    pub session_id: felt252,
    pub root: felt252,
    pub seller: ContractAddress,
    pub buyer: ContractAddress,
    pub status: ListingStatus,
    pub challenge: felt252,
    pub price: u256,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
pub enum OrderStatus {
    Open,
    Sold,
    Refunded,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
pub struct Order {
    pub session_id: felt252,
    pub buyer: ContractAddress,
    pub challenge: felt252,
    pub amount: u256,
    pub status: OrderStatus,
}

#[starknet::interface]
pub trait IMarketplace<TContractState> {
    fn create_listing(ref self: TContractState, token_id: u256, price: u256) -> u256;
    fn cancel_listing(ref self: TContractState, listing_id: u256);
    fn open_purchase(
        ref self: TContractState, listing_id: u256, challenge: felt252, amount: u256
    );
    fn refund_purchase(ref self: TContractState, listing_id: u256);
    fn settle_purchase(
        ref self: TContractState,
        listing_id: u256,
        buyer: ContractAddress,
        challenge_key: u64,
        proof: Span<felt252>,
    );
    fn get_listing(self: @TContractState, listing_id: u256) -> Listing;
    fn get_listing_status(self: @TContractState, listing_id: u256) -> ListingStatus;
    fn get_listing_count(self: @TContractState) -> u256;
    fn get_pox_address(self: @TContractState) -> ContractAddress;
    fn get_listing_by_session(self: @TContractState, session_id: felt252) -> u256;
    fn get_payment_token(self: @TContractState) -> ContractAddress;
    fn get_purchase_timeout(self: @TContractState) -> u64;
    fn is_order_closed(self: @TContractState, session_id: felt252, buyer: ContractAddress) -> bool;
    fn get_order(self: @TContractState, session_id: felt252, buyer: ContractAddress) -> Order;
    fn get_order_status(self: @TContractState, session_id: felt252, buyer: ContractAddress) -> OrderStatus;
    fn get_order_info(self: @TContractState, session_id: felt252, buyer: ContractAddress) -> (felt252, u256);
}
