// Extended ERC20 Token Example
// This example shows how to extend the basic ERC20 with Mintable and Burnable features

#[starknet::contract]
mod ExtendedERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Empty hooks implementation
    impl ERC20HooksImpl = ERC20HooksEmptyImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_supply: u256,
        recipient: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        owner: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.ownable.initializer(owner);
        self.erc20.mint(recipient, initial_supply);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        // Mint new tokens - only owner can mint
        #[external(v0)]
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.mint(recipient, amount);
        }

        // Burn tokens from caller's balance
        #[external(v0)]
        fn burn(ref self: ContractState, amount: u256) {
            let caller = starknet::get_caller_address();
            self.erc20.burn(caller, amount);
        }
    }
}
