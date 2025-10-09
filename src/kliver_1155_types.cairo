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

#[generate_trait]
pub impl TokenDataToCreateImpl of TokenDataToCreateTrait {
    fn new(release_hour: u64, release_amount: u256) -> TokenDataToCreate {
        TokenDataToCreate { release_hour, release_amount }
    }
}

#[derive(Drop, Serde)]
pub struct SimulationDataToCreate {
    pub simulation_id: felt252,
    pub token_id: u256,
    pub expiration_timestamp: u64,
}

#[generate_trait]
pub impl SimulationDataToCreateImpl of SimulationDataToCreateTrait {
    fn new(simulation_id: felt252, token_id: u256, expiration_timestamp: u64) -> SimulationDataToCreate {
        SimulationDataToCreate { simulation_id, token_id, expiration_timestamp }
    }
}

#[derive(Drop, starknet::Event)]
pub struct TokenCreated {
    #[key]
    pub token_id: u256,
    pub creator: ContractAddress,
    pub release_hour: u64,
    pub release_amount: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Simulation {
    pub simulation_id: felt252,
    pub token_id: u256,
    pub creator: ContractAddress,
    pub expiration_timestamp: u64,
}

#[generate_trait]
pub impl SimulationImpl of SimulationTrait {
    fn new(simulation_id: felt252, token_id: u256, creator: ContractAddress, expiration_timestamp: u64) -> Simulation {
        Simulation { simulation_id, token_id, creator, expiration_timestamp }
    }
}

#[derive(Drop, starknet::Event)]
pub struct SimulationRegistered {
    #[key]
    pub simulation_id: felt252,
    pub token_id: u256,
    pub creator: ContractAddress,
    pub expiration_timestamp: u64,
}