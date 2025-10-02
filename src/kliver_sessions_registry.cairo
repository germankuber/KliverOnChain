use starknet::ContractAddress;

/// Interface for Kliver Registry
#[starknet::interface]
pub trait IKliverRegistry<TContractState> {
    /// Register a character version with its ID and hash (only owner)
    fn register_character_version(ref self: TContractState, character_version_id: felt252, character_version_hash: felt252);
    
    /// Verify if a character version ID matches its expected hash
    fn verify_character_version(self: @TContractState, character_version_id: felt252, character_version_hash: felt252) -> bool;
    
    /// Get the hash for a character version ID
    fn get_character_version_hash(self: @TContractState, character_version_id: felt252) -> felt252;
    
    fn get_owner(self: @TContractState) -> ContractAddress;
}

/// Kliver Registry Contract
#[starknet::contract]
pub mod KliverRegistry {
    use super::IKliverRegistry;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, ContractAddress};
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        /// Maps character version ID to its hash
        character_versions: Map<felt252, felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        assert(!owner.is_zero(), 'Owner cannot be zero');
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl KliverRegistryImpl of IKliverRegistry<ContractState> {
        fn register_character_version(ref self: ContractState, character_version_id: felt252, character_version_hash: felt252) {
            // Only owner can register character versions
            self._assert_only_owner();
            
            // Validate inputs
            assert(character_version_id != 0, 'Version ID cannot be zero');
            assert(character_version_hash != 0, 'Version hash cannot be zero');
            
            // Check if character version ID is already registered
            let existing_hash = self.character_versions.read(character_version_id);
            assert(existing_hash == 0, 'Version ID already registered');
            
            // Save the character version
            self.character_versions.write(character_version_id, character_version_hash);
        }
        
        fn verify_character_version(self: @ContractState, character_version_id: felt252, character_version_hash: felt252) -> bool {
            // Validate inputs
            assert(character_version_id != 0, 'Version ID cannot be zero');
            assert(character_version_hash != 0, 'Version hash cannot be zero');
            
            // Get the stored hash for this character version ID
            let stored_hash = self.character_versions.read(character_version_id);
            
            // Return true if the provided hash matches the stored hash
            stored_hash != 0 && stored_hash == character_version_hash
        }
        
        fn get_character_version_hash(self: @ContractState, character_version_id: felt252) -> felt252 {
            // Validate input
            assert(character_version_id != 0, 'Version ID cannot be zero');
            
            // Get the stored hash for this character version ID
            let stored_hash = self.character_versions.read(character_version_id);
            
            // If no hash is stored, panic with error
            assert(stored_hash != 0, 'Character version not found');
            
            stored_hash
        }
        
        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Not owner');
        }
    }
}