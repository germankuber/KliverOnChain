// SPDX-License-Identifier: MIT
#[starknet::contract]
mod SessionsMarketplace {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::Zero;
    use super::super::session_registry::{
        ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait
    };
    use super::super::kliver_registry::{IVerifierDispatcher, IVerifierDispatcherTrait};

    // Estados posibles de un listing
    #[allow(starknet::store_no_default_variant)]
    #[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
    enum ListingStatus {
        Open,
        Purchased,
        Sold,
        Cancelled,
    }

    // Estructura de un listing
    #[derive(Drop, Serde, Copy, starknet::Store)]
    struct Listing {
        session_id: felt252,
        root: felt252,
        seller: ContractAddress,
        buyer: ContractAddress,
        status: ListingStatus,
        challenge: felt252,
        price: u256,
    }

    #[storage]
    struct Storage {
        // Direcciones de los contratos
        registry: ContractAddress,
        verifier: ContractAddress,
        
        // Gestión de listings
        listings: Map<u256, Listing>,
        listing_counter: u256,
        
        // Mapeo de session_id a listing_id
        session_to_listing: Map<felt252, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ListingCreated: ListingCreated,
        PurchaseOpened: PurchaseOpened,
        ProofSubmitted: ProofSubmitted,
        Sold: Sold,
        ListingCancelled: ListingCancelled,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCreated {
        #[key]
        listing_id: u256,
        #[key]
        seller: ContractAddress,
        session_id: felt252,
        root: felt252,
        price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PurchaseOpened {
        #[key]
        listing_id: u256,
        #[key]
        buyer: ContractAddress,
        challenge: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ProofSubmitted {
        #[key]
        listing_id: u256,
        verified: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct Sold {
        #[key]
        listing_id: u256,
        seller: ContractAddress,
        buyer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCancelled {
        #[key]
        listing_id: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        registry_address: ContractAddress,
        verifier_address: ContractAddress
    ) {
        assert(!registry_address.is_zero(), 'Invalid registry address');
        assert(!verifier_address.is_zero(), 'Invalid verifier address');

        self.registry.write(registry_address);
        self.verifier.write(verifier_address);
        self.listing_counter.write(0);
    }

    #[abi(embed_v0)]
    impl MarketplaceImpl of IMarketplace<ContractState> {
        // ============ SELLER FUNCTIONS ============

        // Crear un nuevo listing
        fn create_listing(
            ref self: ContractState,
            session_id: felt252,
            price: u256
        ) -> u256 {
            let caller = get_caller_address();
            
            // Verificar que no exista un listing para esta sesión
            let existing = self.session_to_listing.read(session_id);
            assert(existing == 0, 'Listing already exists');

            // Obtener el root del registry
            let registry = ISessionRegistryDispatcher {
                contract_address: self.registry.read()
            };
            let session_info = registry.get_session_info(session_id);
            let root = session_info.root_hash;
            assert(root != 0, 'Session not found in registry');

            // Verificar que el caller sea el owner de la sesión
            let session_owner = session_info.author;
            assert(caller == session_owner, 'Not session owner');

            // Crear el listing
            let listing_id = self.listing_counter.read() + 1;
            self.listing_counter.write(listing_id);

            let listing = Listing {
                session_id,
                root,
                seller: caller,
                buyer: 0_felt252.try_into().unwrap(),
                status: ListingStatus::Open,
                challenge: 0,
                price,
            };

            self.listings.write(listing_id, listing);
            self.session_to_listing.write(session_id, listing_id);

            // Emitir evento
            self.emit(ListingCreated {
                listing_id,
                seller: caller,
                session_id,
                root,
                price,
            });

            listing_id
        }

        // Cancelar un listing (solo seller)
        fn cancel_listing(ref self: ContractState, listing_id: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.read(listing_id);

            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Open, 'Cannot cancel');

            listing.status = ListingStatus::Cancelled;
            self.listings.write(listing_id, listing);

            self.emit(ListingCancelled { listing_id });
        }

        // ============ BUYER FUNCTIONS ============

        // Abrir una compra y establecer el challenge
        fn open_purchase(
            ref self: ContractState,
            listing_id: u256,
            challenge: felt252
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.read(listing_id);

            // Validaciones
            assert(listing.status == ListingStatus::Open, 'Listing not open');
            assert(challenge != 0, 'Invalid challenge');
            assert(caller != listing.seller, 'Seller cannot buy own listing');

            // Actualizar el listing
            listing.buyer = caller;
            listing.challenge = challenge;
            listing.status = ListingStatus::Purchased;
            self.listings.write(listing_id, listing);

            // Emitir evento
            self.emit(PurchaseOpened {
                listing_id,
                buyer: caller,
                challenge,
            });

            // TODO: Aquí podrías agregar lógica de pago/escrow
            // Por ejemplo, transferir fondos a un contrato de escrow
        }

        // ============ PROOF SUBMISSION (On-chain) ============

        // Verificación on-chain completa
        fn submit_proof_and_verify(
            ref self: ContractState,
            listing_id: u256,
            proof: Span<felt252>,
            public_inputs: Span<felt252>
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.read(listing_id);

            // Validaciones
            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Purchased, 'Not in purchased state');
            
            // Verificar que los public inputs coincidan
            assert(public_inputs.len() >= 2, 'Invalid public inputs');
            let session_root = *public_inputs.at(0);
            let challenge = *public_inputs.at(1);
            
            assert(session_root == listing.root, 'Root mismatch');
            assert(challenge == listing.challenge, 'Challenge mismatch');

            // Llamar al verifier
            let verifier_address = self.verifier.read();
            let verifier = IVerifierDispatcher {
                contract_address: verifier_address
            };
            let result = verifier.verify_ultra_starknet_honk_proof(proof);
            let is_valid = result.is_some();

            // Emitir evento de proof
            self.emit(ProofSubmitted {
                listing_id,
                verified: is_valid,
            });

            // Si la prueba es válida, marcar como vendido
            if is_valid {
                listing.status = ListingStatus::Sold;
                self.listings.write(listing_id, listing);

                self.emit(Sold {
                    listing_id,
                    seller: listing.seller,
                    buyer: listing.buyer,
                });

                // TODO: Aquí se liberaría el pago del escrow al seller
            }
        }

        // ============ VIEW FUNCTIONS ============

        fn get_listing(self: @ContractState, listing_id: u256) -> Listing {
            self.listings.read(listing_id)
        }

        fn get_listing_status(self: @ContractState, listing_id: u256) -> ListingStatus {
            let listing = self.listings.read(listing_id);
            listing.status
        }

        fn get_listing_count(self: @ContractState) -> u256 {
            self.listing_counter.read()
        }

        fn get_registry_address(self: @ContractState) -> ContractAddress {
            self.registry.read()
        }

        fn get_listing_by_session(self: @ContractState, session_id: felt252) -> u256 {
            self.session_to_listing.read(session_id)
        }
    }

    #[starknet::interface]
    trait IMarketplace<TContractState> {
        // Seller functions
        fn create_listing(
            ref self: TContractState,
            session_id: felt252,
            price: u256
        ) -> u256;
        fn cancel_listing(ref self: TContractState, listing_id: u256);
        
        // Buyer functions
        fn open_purchase(
            ref self: TContractState,
            listing_id: u256,
            challenge: felt252
        );
        
        // Proof submission
        fn submit_proof_and_verify(
            ref self: TContractState,
            listing_id: u256,
            proof: Span<felt252>,
            public_inputs: Span<felt252>
        );
        
        // View functions
        fn get_listing(self: @TContractState, listing_id: u256) -> Listing;
        fn get_listing_status(self: @TContractState, listing_id: u256) -> ListingStatus;
        fn get_listing_count(self: @TContractState) -> u256;
        fn get_registry_address(self: @TContractState) -> ContractAddress;
        fn get_listing_by_session(self: @TContractState, session_id: felt252) -> u256;
    }
}