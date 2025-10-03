use starknet::ContractAddress;

/// Interface for Kliver User NFT (Soulbound)
#[starknet::interface]
pub trait IKliverNFT<TContractState> {
    /// Mint NFT to a user when they login to Kliver platform (only owner)
    fn mint_to_user(ref self: TContractState, to: ContractAddress);
    
    /// Check if a user already has a Kliver NFT
    fn user_has_nft(self: @TContractState, user: ContractAddress) -> bool;
    
    /// Get total number of minted tokens
    fn total_supply(self: @TContractState) -> u256;
    
    /// Get the token ID owned by a user (returns 0 if no NFT)
    fn get_user_token_id(self: @TContractState, user: ContractAddress) -> u256;
    
    /// Get when a token was minted
    fn get_minted_at(self: @TContractState, token_id: u256) -> u64;
    
    /// Burn a user's NFT (only owner, for account deletion)
    fn burn_user_nft(ref self: TContractState, user: ContractAddress);
}

/// Events for Kliver NFT
#[derive(Drop, starknet::Event)]
pub struct KliverUserMinted {
    #[key]
    pub token_id: u256,
    #[key]
    pub to: ContractAddress,
    pub minted_at: u64,
}

#[derive(Drop, starknet::Event)]
pub struct KliverUserBurned {
    #[key]
    pub token_id: u256,
    #[key]
    pub from: ContractAddress,
    pub burned_at: u64,
}

#[starknet::contract]
pub mod KliverNFT {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ContractAddress, ClassHash, get_block_timestamp};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess};
    use core::num::traits::Zero;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // ERC721 Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        
        // Kliver NFT specific storage
        total_supply: u256,
        user_to_token: Map<ContractAddress, u256>,
        minted_at: Map<u256, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        KliverUserMinted: super::KliverUserMinted,
        KliverUserBurned: super::KliverUserBurned,
    }

    pub mod Errors {
        pub const USER_ALREADY_HAS_NFT: felt252 = 'User already has Kliver NFT';
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const TOKEN_NOT_FOUND: felt252 = 'Token not found';
        pub const NON_TRANSFERABLE: felt252 = 'Kliver NFT is soulbound';
        pub const USER_HAS_NO_NFT: felt252 = 'User has no NFT to burn';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        base_uri: ByteArray  // ← Ahora es parametrizable
    ) {
        let name = "Kliver  Registry ";
        let symbol = "Kliver AI";

        self.erc721.initializer(name, symbol, base_uri);
        self.ownable.initializer(owner);
        self.total_supply.write(0);
    }

    // SOULBOUND: Override transfer hooks to make NFT non-transferable
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let from = self.owner_of(token_id);
            
            // Allow minting (from == 0) and burning (to == 0)
            // Block all transfers (from != 0 && to != 0)
            if from.is_non_zero() && to.is_non_zero() {
                panic!("{}", Errors::NON_TRANSFERABLE);
            }
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            // No additional logic needed after update
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl KliverNFTImpl of super::IKliverNFT<ContractState> {
        fn mint_to_user(ref self: ContractState, to: ContractAddress) {
            self.ownable.assert_only_owner();
            
            // Validate address is not zero
            assert(to.is_non_zero(), Errors::INVALID_ADDRESS);
            
            // Check if user already has an NFT
            assert(!self.user_has_nft(to), Errors::USER_ALREADY_HAS_NFT);
            
            // Generate token ID (starting from 1)
            let current_supply = self.total_supply.read();
            let token_id = current_supply + 1;
            
            // Mint the NFT
            self.erc721.mint(to, token_id);
            
            // Update mappings
            self.user_to_token.write(to, token_id);
            let timestamp = get_block_timestamp();
            self.minted_at.write(token_id, timestamp);
            
            // Update total supply
            self.total_supply.write(token_id);
            
            // Emit event
            self.emit(super::KliverUserMinted {
                token_id,
                to,
                minted_at: timestamp
            });
        }

        fn burn_user_nft(ref self: ContractState, user: ContractAddress) {
            self.ownable.assert_only_owner();
            
            // Get user's token ID
            let token_id = self.user_to_token.read(user);
            assert(token_id != 0, Errors::USER_HAS_NO_NFT);
            
            // Burn the NFT
            self.erc721.burn(token_id);
            
            // Clean up mappings
            self.user_to_token.write(user, 0);
            self.minted_at.write(token_id, 0);
            
            // Emit event
            self.emit(super::KliverUserBurned {
                token_id,
                from: user,
                burned_at: get_block_timestamp()
            });
        }

        fn user_has_nft(self: @ContractState, user: ContractAddress) -> bool {
            let token_id = self.user_to_token.read(user);
            token_id != 0
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn get_user_token_id(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_to_token.read(user)
        }

        fn get_minted_at(self: @ContractState, token_id: u256) -> u64 {
            self.minted_at.read(token_id)
        }
    }
}