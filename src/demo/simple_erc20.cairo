#[starknet::contract]
mod SimpleERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    
    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    
    // Constants
    const TOTAL_SUPPLY: u256 = 1000000000000000000000000000000_u256; // 1 billion tokens (with 18 decimals)
    const CLAIM_AMOUNT: u256 = 100000000000000000000_u256; // 100 tokens per claim
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        TokensClaimed: TokensClaimed,
    }
    
    #[derive(Drop, starknet::Event)]
    struct TokensClaimed {
        #[key]
        claimer: ContractAddress,
        amount: u256,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize with fixed values
        self.erc20.initializer("Kliver Demo", "KDemo");
        // Mint all supply to the contract itself
        self.erc20.mint(starknet::get_contract_address(), TOTAL_SUPPLY);
    }
    
    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Public function for anyone to claim tokens
        /// Can claim unlimited times
        #[external(v0)]
        fn claim(ref self: ContractState) {
            let caller = starknet::get_caller_address();
            
            // Transfer tokens from contract to caller using internal function
            let contract_address = starknet::get_contract_address();
            self.erc20._transfer(contract_address, caller, CLAIM_AMOUNT);
            
            // Emit event
            self.emit(TokensClaimed { claimer: caller, amount: CLAIM_AMOUNT });
        }
        
        /// Get the amount of tokens that can be claimed
        #[external(v0)]
        fn claim_amount(self: @ContractState) -> u256 {
            CLAIM_AMOUNT
        }
    }
}