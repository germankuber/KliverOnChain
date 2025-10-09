use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct TokenInfo {
    pub release_hour: u64,
    pub release_amount: u256,
}

#[derive(Drop, Serde)]
pub struct TokenDataToCreate {
    pub release_hour: u64,
    pub release_amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TokenCreated {
    #[key]
    pub token_id: u256,
    pub creator: ContractAddress,
    pub release_hour: u64,
    pub release_amount: u256,
}