// SPDX-License-Identifier: MIT
#[starknet::contract]
mod SessionsMarketplace {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, StoragePathEntry};
    use core::num::traits::Zero;

    // Estados posibles de un listing
    #[derive(Drop, Serde, Copy, PartialEq, starknet::Store)]
    #[allow(starknet::store_no_default_variant)]
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
        registry: ContractAddress,
        verifier: ContractAddress,
        listings: Map<u256, Listing>,
        listing_counter: u256,
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
    impl SessionsMarketplaceImpl of ISessionsMarketplace<ContractState> {
        fn create_listing(
            ref self: ContractState,
            session_id: felt252,
            root: felt252,
            price: u256
        ) -> u256 {
            let caller = get_caller_address();
            
            let existing = self.session_to_listing.entry(session_id).read();
            assert(existing == 0, 'Listing already exists');
            assert(root != 0, 'Invalid root');

            let listing_id = self.listing_counter.read() + 1;
            self.listing_counter.write(listing_id);

            let zero_address: ContractAddress = Zero::zero();
            let listing = Listing {
                session_id,
                root,
                seller: caller,
                buyer: zero_address,
                status: ListingStatus::Open,
                challenge: 0,
                price,
            };

            self.listings.entry(listing_id).write(listing);
            self.session_to_listing.entry(session_id).write(listing_id);

            self.emit(ListingCreated {
                listing_id,
                seller: caller,
                session_id,
                root,
                price,
            });

            listing_id
        }

        fn cancel_listing(ref self: ContractState, listing_id: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.entry(listing_id).read();

            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Open, 'Cannot cancel');

            listing.status = ListingStatus::Cancelled;
            self.listings.entry(listing_id).write(listing);

            self.emit(ListingCancelled { listing_id });
        }

        fn open_purchase(
            ref self: ContractState,
            listing_id: u256,
            challenge: felt252
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.entry(listing_id).read();

            assert(listing.status == ListingStatus::Open, 'Listing not open');
            assert(challenge != 0, 'Invalid challenge');
            assert(caller != listing.seller, 'Seller cannot buy');

            listing.buyer = caller;
            listing.challenge = challenge;
            listing.status = ListingStatus::Purchased;
            self.listings.entry(listing_id).write(listing);

            self.emit(PurchaseOpened {
                listing_id,
                buyer: caller,
                challenge,
            });
        }

        fn submit_proof_and_verify(
            ref self: ContractState,
            listing_id: u256,
            proof: Span<felt252>,
            public_inputs: Span<felt252>
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.entry(listing_id).read();

            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Purchased, 'Not in purchased state');
            
            assert(public_inputs.len() >= 2, 'Invalid public inputs');
            let session_root = *public_inputs.at(0);
            let challenge = *public_inputs.at(1);
            
            assert(session_root == listing.root, 'Root mismatch');
            assert(challenge == listing.challenge, 'Challenge mismatch');

            // Verificación simplificada - integra con tu verifier real
            let is_valid = self._verify_proof(proof, public_inputs);

            self.emit(ProofSubmitted {
                listing_id,
                verified: is_valid,
            });

            if is_valid {
                listing.status = ListingStatus::Sold;
                self.listings.entry(listing_id).write(listing);

                self.emit(Sold {
                    listing_id,
                    seller: listing.seller,
                    buyer: listing.buyer,
                });
            }
        }

        fn get_listing(self: @ContractState, listing_id: u256) -> Listing {
            self.listings.entry(listing_id).read()
        }

        fn get_listing_status(self: @ContractState, listing_id: u256) -> ListingStatus {
            let listing = self.listings.entry(listing_id).read();
            listing.status
        }

        fn get_listing_count(self: @ContractState) -> u256 {
            self.listing_counter.read()
        }

        fn get_registry_address(self: @ContractState) -> ContractAddress {
            self.registry.read()
        }

        fn get_verifier_address(self: @ContractState) -> ContractAddress {
            self.verifier.read()
        }

        fn get_listing_by_session(self: @ContractState, session_id: felt252) -> u256 {
            self.session_to_listing.entry(session_id).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _verify_proof(
            self: @ContractState,
            proof: Span<felt252>,
            public_inputs: Span<felt252>
        ) -> bool {
            // Verificaciones básicas
            if proof.len() < 4 {
                return false;
            }

            let session_root = *public_inputs.at(0);
            let challenge = *public_inputs.at(1);

            if session_root == 0 || challenge == 0 {
                return false;
            }

            // Aquí integrarías con tu verifier real
            // Por ahora retornamos true para testing
            true
        }
    }

    #[starknet::interface]
    trait ISessionsMarketplace<TContractState> {
        fn create_listing(
            ref self: TContractState,
            session_id: felt252,
            root: felt252,
            price: u256
        ) -> u256;
        fn cancel_listing(ref self: TContractState, listing_id: u256);
        fn open_purchase(
            ref self: TContractState,
            listing_id: u256,
            challenge: felt252
        );
        fn submit_proof_and_verify(
            ref self: TContractState,
            listing_id: u256,
            proof: Span<felt252>,
            public_inputs: Span<felt252>
        );
        fn get_listing(self: @TContractState, listing_id: u256) -> Listing;
        fn get_listing_status(self: @TContractState, listing_id: u256) -> ListingStatus;
        fn get_listing_count(self: @TContractState) -> u256;
        fn get_registry_address(self: @TContractState) -> ContractAddress;
        fn get_verifier_address(self: @TContractState) -> ContractAddress;
        fn get_listing_by_session(self: @TContractState, session_id: felt252) -> u256;
    }
}