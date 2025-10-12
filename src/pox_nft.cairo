use starknet::ContractAddress;

// Interface for POX NFT (non-transferable, non-burnable)
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
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PoxInfo {
    pub session_id: felt252,
    pub root_hash: felt252,
    pub simulation_id: felt252,
    pub score: u32,
}

#[derive(Drop, starknet::Event)]
pub struct PoxMinted {
    #[key]
    pub token_id: u256,
    #[key]
    pub to: ContractAddress,
    pub session_id: felt252,
    pub root_hash: felt252,
    pub simulation_id: felt252,
    pub score: u32,
}

#[starknet::contract]
pub mod PoxNFT {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use kliver_on_chain::kliver_nft::{IKliverNFTDispatcher, IKliverNFTDispatcherTrait};

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
        // POX specific storage
        registry: ContractAddress,
        kliver_nft: ContractAddress,
        total_supply: u256,
        user_to_token: Map<ContractAddress, u256>,
        pox_info: Map<u256, super::PoxInfo>,
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
        PoxMinted: super::PoxMinted,
    }

    pub mod Errors {
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const ONLY_REGISTRY: felt252 = 'Only registry can call';
        pub const ALREADY_HAS_NFT: felt252 = 'User already has POX NFT';
        pub const NON_TRANSFERABLE: felt252 = 'POX NFT is non-transferable';
        pub const TOKEN_NOT_FOUND: felt252 = 'Token not found';
        pub const NO_KLIVER_NFT: felt252 = 'Author has no Kliver NFT';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        base_uri: ByteArray,
        registry: ContractAddress,
        kliver_nft: ContractAddress,
    ) {
        let name = "POX NFT";
        let symbol = "POX";
        self.erc721.initializer(name, symbol, base_uri);
        self.ownable.initializer(owner);
        assert(registry.is_non_zero(), Errors::INVALID_ADDRESS);
        assert(kliver_nft.is_non_zero(), Errors::INVALID_ADDRESS);
        self.registry.write(registry);
        self.kliver_nft.write(kliver_nft);
        self.total_supply.write(0);
    }

    // Make NFT strictly soulbound: only allow mint (from == 0, to != 0)
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let from = self.ERC721_owners.read(token_id);
            // Allow only minting
            assert(from.is_zero() && to.is_non_zero(), Errors::NON_TRANSFERABLE);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) { }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // Internal helpers
    fn assert_only_registry(self: @ContractState) {
        let caller = get_caller_address();
        let registry = self.registry.read();
        assert(caller == registry, Errors::ONLY_REGISTRY);
    }

    #[abi(embed_v0)]
    impl PoxNFTImpl of super::IPoxNFT<ContractState> {
        fn get_registry(self: @ContractState) -> ContractAddress {
            self.registry.read()
        }

        fn set_registry(ref self: ContractState, new_registry: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(new_registry.is_non_zero(), Errors::INVALID_ADDRESS);
            self.registry.write(new_registry);
        }

        fn get_kliver_nft(self: @ContractState) -> ContractAddress {
            self.kliver_nft.read()
        }

        fn set_kliver_nft(ref self: ContractState, new_kliver_nft: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(new_kliver_nft.is_non_zero(), Errors::INVALID_ADDRESS);
            self.kliver_nft.write(new_kliver_nft);
        }

        fn mint(
            ref self: ContractState,
            session_id: felt252,
            root_hash: felt252,
            simulation_id: felt252,
            score: u32,
            author: ContractAddress,
        ) {
            // Only registry can mint
            assert_only_registry(@self);

            // Validate author
            assert(author.is_non_zero(), Errors::INVALID_ADDRESS);

            // Ensure single NFT per author
            let existing = self.user_to_token.read(author);
            assert(existing.is_zero(), Errors::ALREADY_HAS_NFT);

            // Validate the author owns a Kliver NFT
            let kliver_addr = self.kliver_nft.read();
            let kliver = IKliverNFTDispatcher { contract_address: kliver_addr };
            let has = kliver.user_has_nft(author);
            assert(has, Errors::NO_KLIVER_NFT);

            // Next token id (start at 1)
            let current_supply = self.total_supply.read();
            let token_id = current_supply + 1;

            // Mint
            self.erc721.mint(author, token_id);

            // Store relations and info
            self.user_to_token.write(author, token_id);
            self
                .pox_info
                .write(token_id, super::PoxInfo { session_id, root_hash, simulation_id, score });

            // Update supply
            self.total_supply.write(token_id);

            // Event
            self.emit(super::PoxMinted { token_id, to: author, session_id, root_hash, simulation_id, score });
        }

        fn user_has_nft(self: @ContractState, user: ContractAddress) -> bool {
            let token_id = self.user_to_token.read(user);
            token_id != 0
        }

        fn get_user_token_id(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_to_token.read(user)
        }

        fn total_supply(self: @ContractState) -> u256 { self.total_supply.read() }

        fn get_pox_info(self: @ContractState, token_id: u256) -> super::PoxInfo {
            // Check token existence by reading raw owners mapping to avoid OZ revert
            let owner = self.erc721.ERC721_owners.read(token_id);
            assert(owner.is_non_zero(), Errors::TOKEN_NOT_FOUND);
            self.pox_info.read(token_id)
        }
    }
}
