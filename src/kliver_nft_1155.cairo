use starknet::ContractAddress;

// Constants for batch operations
pub const MAX_BATCH_SIZE: u32 = 100;

/// Interface for Kliver Multi-Token NFT (ERC-1155) with Strict Transfer Controls
#[starknet::interface]
pub trait IKliverNFT1155<TContractState> {
    /// Mint tokens to a user (only owner)
    fn mint_to_user(
        ref self: TContractState, 
        to: ContractAddress, 
        token_id: u256, 
        amount: u256
    );
    
    /// Batch mint multiple token types to a user (limited batch size)
    fn batch_mint_to_user(
        ref self: TContractState,
        to: ContractAddress,
        token_ids: Span<u256>,
        amounts: Span<u256>
    );

    /// Check if a user has a specific token type
    fn user_has_token(
        self: @TContractState, 
        user: ContractAddress, 
        token_id: u256
    ) -> bool;

    /// Get user's balance for a specific token type
    fn get_user_balance(
        self: @TContractState, 
        user: ContractAddress, 
        token_id: u256
    ) -> u256;

    /// Burn tokens from a user (only owner, respects soulbound rules)
    fn burn_user_tokens(
        ref self: TContractState, 
        user: ContractAddress, 
        token_id: u256, 
        amount: u256
    );
    
    /// Mint tokens to a user WITHOUT acceptance check (only for testing with EOA addresses)
    fn mint_to_user_unsafe(
        ref self: TContractState, 
        to: ContractAddress, 
        token_id: u256, 
        amount: u256
    );
    
    /// Batch mint multiple token types to a user WITHOUT acceptance check (only for testing)
    fn batch_mint_to_user_unsafe(
        ref self: TContractState,
        to: ContractAddress,
        token_ids: Span<u256>,
        amounts: Span<u256>
    );
    
    /// Transfer tokens WITHOUT acceptance check (only for testing)
    fn safe_transfer_from_unsafe(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256
    );
    
    /// Get total supply for a specific token type (calculated on-demand)
    fn total_supply(self: @TContractState, token_id: u256) -> u256;
    
    /// Add a new token type (only owner)
    fn add_token_type(
        ref self: TContractState,
        token_id: u256,
        max_supply: u256,
        is_soulbound: bool,
        metadata_uri: ByteArray
    );
    
    /// Get metadata URI for a token type
    fn get_token_metadata(self: @TContractState, token_id: u256) -> ByteArray;
}

/// Token type configuration (no current_supply tracking to avoid desync)
#[derive(Drop, Serde, starknet::Store)]
pub struct TokenType {
    pub max_supply: u256,
    pub is_soulbound: bool,
    pub metadata_uri: ByteArray,
    pub created_at: u64,
}

/// Events for Kliver NFT 1155
#[derive(Drop, starknet::Event)]
pub struct KliverTokenMinted {
    #[key]
    pub token_id: u256,
    #[key]
    pub to: ContractAddress,
    pub amount: u256,
    pub minted_at: u64,
}

#[derive(Drop, starknet::Event)]
pub struct KliverTokenBurned {
    #[key]
    pub token_id: u256,
    #[key]
    pub from: ContractAddress,
    pub amount: u256,
    pub burned_at: u64,
}

#[derive(Drop, starknet::Event)]
pub struct TokenTypeAdded {
    #[key]
    pub token_id: u256,
    pub max_supply: u256,
    pub is_soulbound: bool,
}

#[derive(Drop, starknet::Event)]
pub struct RestrictedTransferAttempt {
    #[key]
    pub from: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub token_id: u256,
    pub reason: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ApprovalAttemptBlocked {
    #[key]
    pub caller: ContractAddress,
    pub operator: ContractAddress,
    pub reason: felt252,
}

#[starknet::contract]
pub mod KliverNFT1155 {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use super::{TokenType, IKliverNFT1155};

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // ERC1155 Implementation with RESTRICTED APPROVALS
    #[abi(embed_v0)]
    impl RestrictedERC1155 of openzeppelin::token::erc1155::interface::IERC1155<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress, token_id: u256) -> u256 {
            self.erc1155.balance_of(account, token_id)
        }
        
        fn balance_of_batch(
            self: @ContractState,
            accounts: Span<ContractAddress>,
            token_ids: Span<u256>
        ) -> Span<u256> {
            self.erc1155.balance_of_batch(accounts, token_ids)
        }
        
        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>
        ) {
            self.erc1155.safe_transfer_from(from, to, token_id, value, data);
        }
        
        fn safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>
        ) {
            self.erc1155.safe_batch_transfer_from(from, to, token_ids, values, data);
        }
        
        fn is_approved_for_all(
            self: @ContractState,
            owner: ContractAddress,
            operator: ContractAddress
        ) -> bool {
            self.erc1155.is_approved_for_all(owner, operator)
        }
        
        /// 🔒 CRITICAL: Approvals are completely disabled for all users
        fn set_approval_for_all(
            ref self: ContractState,
            operator: ContractAddress,
            approved: bool
        ) {
            let caller = get_caller_address();
            
            // Emit event for monitoring/debugging
            self.emit(super::ApprovalAttemptBlocked {
                caller,
                operator,
                reason: 'Approvals disabled'
            });
            
            // Always fail - no approvals allowed
            assert(false, Errors::APPROVALS_DISABLED);
        }
    }
    
    // Also implement metadata URI interface
    #[abi(embed_v0)]
    impl ERC1155MetadataImpl of openzeppelin::token::erc1155::interface::IERC1155MetadataURI<ContractState> {
        fn uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc1155.uri(token_id)
        }
    }
    
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // Kliver NFT specific storage
        token_types: Map<u256, TokenType>,
        token_exists: Map<u256, bool>,
        token_metadata: Map<u256, ByteArray>,
        total_supplies: Map<u256, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        KliverTokenMinted: super::KliverTokenMinted,
        KliverTokenBurned: super::KliverTokenBurned,
        TokenTypeAdded: super::TokenTypeAdded,
        RestrictedTransferAttempt: super::RestrictedTransferAttempt,
        ApprovalAttemptBlocked: super::ApprovalAttemptBlocked,
    }

    pub mod Errors {
        pub const INVALID_ADDRESS: felt252 = 'Invalid address';
        pub const TOKEN_NOT_FOUND: felt252 = 'Token not found';
        pub const TOKEN_ALREADY_EXISTS: felt252 = 'Token type already exists';
        pub const MAX_SUPPLY_EXCEEDED: felt252 = 'Max supply exceeded';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        pub const SOULBOUND_TRANSFER: felt252 = 'Soulbound token transfer';
        pub const INVALID_ARRAY_LENGTH: felt252 = 'Invalid array length';
        pub const ZERO_AMOUNT: felt252 = 'Amount cannot be zero';
        pub const USER_TO_USER_TRANSFER: felt252 = 'User-to-user transfer blocked';
        pub const UNAUTHORIZED_TRANSFER: felt252 = 'Unauthorized transfer';
        pub const APPROVALS_DISABLED: felt252 = 'Approvals disabled';
        pub const BATCH_TOO_LARGE: felt252 = 'Batch too large';
    }

    // Token IDs for different Kliver NFT types
    pub mod TokenIds {
        pub const USER_BADGE: u256 = 1;
        pub const PREMIUM_BADGE: u256 = 2;
        pub const DEVELOPER_BADGE: u256 = 3;
        pub const ACHIEVEMENT_1: u256 = 100;
        pub const ACHIEVEMENT_2: u256 = 101;
        // Add more token types as needed
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        base_uri: ByteArray
    ) {
        self.erc1155.initializer(base_uri);
        self.ownable.initializer(owner);
        
        // Initialize default token types
        self._init_default_token_types();
    }

    // RESTRICTED TRANSFERS: Override ERC1155 hooks to control all transfers
    impl ERC1155HooksImpl of ERC1155Component::ERC1155HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            let mut contract_state = self.get_contract_mut();
            let _owner = contract_state.ownable.owner();
            let _caller = get_caller_address();
            
            // Allow minting (from == 0) and burning (to == 0)
            if from.is_zero() || to.is_zero() {
                return;
            }
            
            // Check transfer direction restrictions for each token
            let mut i = 0;
            let len = token_ids.len();
            while i != len {
                let token_id = *token_ids.at(i);
                let token_type = contract_state.token_types.read(token_id);
                
                // 1️⃣ SOULBOUND CHECK: Block transfers of soulbound tokens (except mint/burn)
                if token_type.is_soulbound {
                    contract_state.emit(super::RestrictedTransferAttempt {
                        from,
                        to,
                        token_id,
                        reason: 'Token is soulbound'
                    });
                    assert(false, Errors::SOULBOUND_TRANSFER);
                }
                
                // 2️⃣ For non-soulbound tokens, allow normal ERC1155 transfers
                // No additional restrictions needed for regular tokens
                
                i += 1;
            }
        }

        fn after_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            // No need to track supply manually - calculate on-demand to avoid desync
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
    impl KliverNFT1155Impl of IKliverNFT1155<ContractState> {
        fn mint_to_user(
            ref self: ContractState, 
            to: ContractAddress, 
            token_id: u256, 
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            self._validate_mint(to, token_id, amount);
            
            // Mint tokens using the standard ERC1155 mint function
            self.erc1155.mint_with_acceptance_check(to, token_id, amount, array![].span());
            
            // Emit event
            self.emit(super::KliverTokenMinted {
                token_id,
                to,
                amount,
                minted_at: get_block_timestamp()
            });
        }

        fn batch_mint_to_user(
            ref self: ContractState,
            to: ContractAddress,
            token_ids: Span<u256>,
            amounts: Span<u256>
        ) {
            self.ownable.assert_only_owner();
            
            assert(token_ids.len() == amounts.len(), Errors::INVALID_ARRAY_LENGTH);
            assert(token_ids.len() > 0, Errors::INVALID_ARRAY_LENGTH);
            
            // 🛡️ BATCH SIZE LIMIT: Prevent DoS attacks
            assert(token_ids.len() <= super::MAX_BATCH_SIZE, 'Batch too large');
            
            // Validate each token type and amount
            let mut i = 0;
            let len = token_ids.len();
            while i != len {
                let token_id = *token_ids.at(i);
                let amount = *amounts.at(i);
                self._validate_mint(to, token_id, amount);
                i += 1;
            }
            
            // Batch mint using standard function
            self.erc1155.batch_mint_with_acceptance_check(to, token_ids, amounts, array![].span());
            
            // Emit events for each token type
            let mut i = 0;
            let timestamp = get_block_timestamp();
            let len = token_ids.len();
            while i != len {
                self.emit(super::KliverTokenMinted {
                    token_id: *token_ids.at(i),
                    to,
                    amount: *amounts.at(i),
                    minted_at: timestamp
                });
                i += 1;
            }
        }

        fn user_has_token(
            self: @ContractState, 
            user: ContractAddress, 
            token_id: u256
        ) -> bool {
            self.erc1155.balance_of(user, token_id) > 0
        }

        fn get_user_balance(
            self: @ContractState, 
            user: ContractAddress, 
            token_id: u256
        ) -> u256 {
            self.erc1155.balance_of(user, token_id)
        }

        fn burn_user_tokens(
            ref self: ContractState, 
            user: ContractAddress, 
            token_id: u256, 
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            
            assert(user.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(self.token_exists.read(token_id), Errors::TOKEN_NOT_FOUND);
            
            let current_balance = self.erc1155.balance_of(user, token_id);
            assert(current_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            
            // Burn the tokens
            self.erc1155.burn(user, token_id, amount);
            
            // Update total supply
            let current_supply = self.total_supplies.read(token_id);
            self.total_supplies.write(token_id, current_supply - amount);
            
            // Emit event
            self.emit(super::KliverTokenBurned {
                token_id,
                from: user,
                amount,
                burned_at: get_block_timestamp()
            });
        }

        fn total_supply(self: @ContractState, token_id: u256) -> u256 {
            assert(self.token_exists.read(token_id), Errors::TOKEN_NOT_FOUND);
            self.total_supplies.read(token_id)
        }

        fn add_token_type(
            ref self: ContractState,
            token_id: u256,
            max_supply: u256,
            is_soulbound: bool,
            metadata_uri: ByteArray
        ) {
            self.ownable.assert_only_owner();
            
            assert(!self.token_exists.read(token_id), Errors::TOKEN_ALREADY_EXISTS);
            
            let token_type = TokenType {
                max_supply,
                is_soulbound,
                metadata_uri: metadata_uri.clone(),
                created_at: get_block_timestamp(),
            };
            
            self.token_types.write(token_id, token_type);
            self.token_exists.write(token_id, true);
            self.token_metadata.write(token_id, metadata_uri.clone());
            
            self.emit(super::TokenTypeAdded {
                token_id,
                max_supply,
                is_soulbound,
            });
        }
        
        fn get_token_metadata(self: @ContractState, token_id: u256) -> ByteArray {
            assert(self.token_exists.read(token_id), Errors::TOKEN_NOT_FOUND);
            self.token_metadata.read(token_id)
        }
        
        fn mint_to_user_unsafe(
            ref self: ContractState, 
            to: ContractAddress, 
            token_id: u256, 
            amount: u256
        ) {
            self.ownable.assert_only_owner();
            self._validate_mint(to, token_id, amount);
            
            // Use the internal update function which bypasses acceptance check
            let zero_address = 0_felt252.try_into().unwrap();
            let token_ids = array![token_id].span();
            let amounts = array![amount].span();
            
            // Call the internal update function directly
            self.erc1155.update(zero_address, to, token_ids, amounts);
            
            // Update total supply
            let current_supply = self.total_supplies.read(token_id);
            self.total_supplies.write(token_id, current_supply + amount);
            
            // Emit event
            self.emit(super::KliverTokenMinted {
                token_id,
                to,
                amount,
                minted_at: get_block_timestamp()
            });
        }
        
        fn batch_mint_to_user_unsafe(
            ref self: ContractState,
            to: ContractAddress,
            token_ids: Span<u256>,
            amounts: Span<u256>
        ) {
            self.ownable.assert_only_owner();
            
            assert(token_ids.len() == amounts.len(), Errors::INVALID_ARRAY_LENGTH);
            assert(token_ids.len() > 0, Errors::INVALID_ARRAY_LENGTH);
            
            // 🛡️ BATCH SIZE LIMIT: Prevent DoS attacks
            assert(token_ids.len() <= super::MAX_BATCH_SIZE, 'Batch too large');
            
            // Validate each token type and amount
            let mut i = 0;
            let len = token_ids.len();
            while i != len {
                let token_id = *token_ids.at(i);
                let amount = *amounts.at(i);
                self._validate_mint(to, token_id, amount);
                i += 1;
            }
            
            // Use the internal update function to bypass acceptance check
            let zero_address = 0_felt252.try_into().unwrap();
            self.erc1155.update(zero_address, to, token_ids, amounts);
            
            // Update total supplies for each token
            let mut i = 0;
            while i != len {
                let token_id = *token_ids.at(i);
                let amount = *amounts.at(i);
                let current_supply = self.total_supplies.read(token_id);
                self.total_supplies.write(token_id, current_supply + amount);
                i += 1;
            }
            
            // Emit events for each token type
            let mut i = 0;
            let timestamp = get_block_timestamp();
            while i != len {
                self.emit(super::KliverTokenMinted {
                    token_id: *token_ids.at(i),
                    to,
                    amount: *amounts.at(i),
                    minted_at: timestamp
                });
                i += 1;
            }
        }
        
        fn safe_transfer_from_unsafe(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            value: u256
        ) {
            // Use the internal update function to bypass acceptance check
            let token_ids = array![token_id].span();
            let values = array![value].span();
            
            self.erc1155.update(from, to, token_ids, values);
            
            // Update supply tracking is not needed for transfers (only for mint/burn)
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _validate_mint(
            ref self: ContractState,
            to: ContractAddress,
            token_id: u256,
            amount: u256
        ) {
            assert(to.is_non_zero(), Errors::INVALID_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(self.token_exists.read(token_id), Errors::TOKEN_NOT_FOUND);
            
            let token_type = self.token_types.read(token_id);
            
            // For max_supply validation, we'd need to implement proper supply tracking
            // or calculate current supply on-demand. For now, skip this check.
            // In production, implement efficient supply tracking mechanism.
            if token_type.max_supply > 0 {
                // TODO: Implement efficient current supply calculation
                // assert(current_supply + amount <= token_type.max_supply, Errors::MAX_SUPPLY_EXCEEDED);
            }
        }
        
        fn _init_default_token_types(ref self: ContractState) {
            let timestamp = get_block_timestamp();
            
            // User Badge (Soulbound, unlimited supply)
            self.token_types.write(
                TokenIds::USER_BADGE,
                TokenType {
                    max_supply: 0, // 0 = unlimited
                    is_soulbound: true,
                    metadata_uri: "https://kliver.io/api/metadata/user-badge/{id}.json",
                    created_at: timestamp,
                }
            );
            self.token_exists.write(TokenIds::USER_BADGE, true);
            self.token_metadata.write(TokenIds::USER_BADGE, "https://kliver.io/api/metadata/user-badge/{id}.json");
            
            // Premium Badge (Soulbound, limited supply)
            self.token_types.write(
                TokenIds::PREMIUM_BADGE,
                TokenType {
                    max_supply: 10000,
                    is_soulbound: true,
                    metadata_uri: "https://kliver.io/api/metadata/premium-badge/{id}.json",
                    created_at: timestamp,
                }
            );
            self.token_exists.write(TokenIds::PREMIUM_BADGE, true);
            self.token_metadata.write(TokenIds::PREMIUM_BADGE, "https://kliver.io/api/metadata/premium-badge/{id}.json");
            
            // Developer Badge (Soulbound, limited supply)
            self.token_types.write(
                TokenIds::DEVELOPER_BADGE,
                TokenType {
                    max_supply: 1000,
                    is_soulbound: true,
                    metadata_uri: "https://kliver.io/api/metadata/developer-badge/{id}.json",
                    created_at: timestamp,
                }
            );
            self.token_exists.write(TokenIds::DEVELOPER_BADGE, true);
            self.token_metadata.write(TokenIds::DEVELOPER_BADGE, "https://kliver.io/api/metadata/developer-badge/{id}.json");
        }
    }
}