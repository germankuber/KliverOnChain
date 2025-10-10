use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct TokenInfo {
    pub release_hour: u64,
    pub release_amount: u256,
    pub special_release: u256,
}

#[derive(Drop, Serde)]
pub struct TokenDataToCreate {
    pub release_hour: u64,
    pub release_amount: u256,
    pub special_release: u256,
}

#[generate_trait]
pub impl TokenDataToCreateImpl of TokenDataToCreateTrait {
    fn new(release_hour: u64, release_amount: u256) -> TokenDataToCreate {
        TokenDataToCreate { release_hour, release_amount, special_release: 0 }
    }
    fn new_with_special_release(
        release_hour: u64, release_amount: u256, special_release: u256,
    ) -> TokenDataToCreate {
        TokenDataToCreate { release_hour, release_amount, special_release }
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
    fn new(
        simulation_id: felt252, token_id: u256, expiration_timestamp: u64,
    ) -> SimulationDataToCreate {
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
    pub special_release: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Simulation {
    pub simulation_id: felt252,
    pub token_id: u256,
    pub creator: ContractAddress,
    pub creation_timestamp: u64,
    pub expiration_timestamp: u64,
}

#[generate_trait]
pub impl SimulationImpl of SimulationTrait {
    fn new(
        simulation_id: felt252,
        token_id: u256,
        creator: ContractAddress,
        creation_timestamp: u64,
        expiration_timestamp: u64,
    ) -> Simulation {
        Simulation { simulation_id, token_id, creator, creation_timestamp, expiration_timestamp }
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

#[derive(Drop, starknet::Event)]
pub struct AddedToWhitelist {
    pub token_id: u256,
    pub wallet: ContractAddress,
    pub simulation_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct RemovedFromWhitelist {
    pub token_id: u256,
    pub wallet: ContractAddress,
    pub simulation_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct SimulationExpirationUpdated {
    pub simulation_id: felt252,
    pub old_expiration: u64,
    pub new_expiration: u64,
}

#[derive(Drop, starknet::Event)]
pub struct TokensClaimed {
    pub token_id: u256,
    pub simulation_id: felt252,
    pub claimer: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SessionPayment {
    pub session_id: felt252,
    pub simulation_id: felt252,
    pub payer: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SessionPaid {
    pub session_id: felt252,
    pub simulation_id: felt252,
    pub payer: ContractAddress,
    pub amount: u256,
    pub token_id: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct HintPayment {
    pub hint_id: felt252,
    pub simulation_id: felt252,
    pub payer: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct HintPaid {
    pub hint_id: felt252,
    pub simulation_id: felt252,
    pub payer: ContractAddress,
    pub amount: u256,
    pub token_id: u256,
}

#[derive(Drop, Serde)]
pub struct ClaimableAmountResult {
    pub simulation_id: felt252,
    pub wallet: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, Serde)]
pub struct SimulationClaimData {
    pub simulation_id: felt252,
    pub claimable_amount: u256,
}

#[derive(Drop, Serde)]
pub struct WalletTokenSummary {
    pub token_id: u256,
    pub wallet: ContractAddress,
    pub current_balance: u256,
    pub token_info: TokenInfo,
    pub total_claimable: u256,
    pub simulations_data: Array<SimulationClaimData>,
}
