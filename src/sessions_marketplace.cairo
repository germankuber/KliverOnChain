// SPDX-License-Identifier: MIT
// Minimal ERC20 interface for escrow transfers (module-level)
// Re-export marketplace interface types and dispatcher at file scope for compatibility
pub use crate::interfaces::marketplace_interface::{
    IMarketplace, IMarketplaceDispatcher, IMarketplaceDispatcherTrait, ListingStatus, OrderStatus,
    Order, Listing,
};

#[starknet::contract]
pub mod SessionsMarketplace {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use super::super::interfaces::verifier::{IVerifierDispatcher, IVerifierDispatcherTrait};
    // Bring marketplace types into scope
    use crate::interfaces::marketplace_interface::{Listing, Order, ListingStatus, OrderStatus};
    // Registry no longer used directly here
    // Types and dispatcher re-exported at file scope

    // use dispatcher imported at module level

    // Types moved to crate::interfaces::sessions_marketplace

    #[storage]
    struct Storage {
        // Direcciones de los contratos
        pox: ContractAddress,
        verifier: ContractAddress,
        // Token de pago (ERC20) y timeout de compra (en segundos)
        payment_token: ContractAddress,
        purchase_timeout: u64,
        // Gestión de listings
        listings: Map<u256, Listing>,
        listing_counter: u256,
        // Mapeo de session_id a listing_id
        session_to_listing: Map<felt252, u256>,
        // Órdenes por (listing_id, buyer)
        orders: Map<(u256, ContractAddress), Order>,
        // Escrow y tiempos por orden (listing_id, buyer)
        escrow_amount: Map<(u256, ContractAddress), u256>,
        purchase_opened_at: Map<(u256, ContractAddress), u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ListingCreated: ListingCreated,
        PurchaseOpened: PurchaseOpened,
        ProofSubmitted: ProofSubmitted,
        Sold: Sold,
        ListingCancelled: ListingCancelled,
        PurchaseRefunded: PurchaseRefunded,
        OrderClosedDetailed: OrderClosedDetailed,
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
        amount: u256,
        opened_at: u64,
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

    #[derive(Drop, starknet::Event)]
    struct PurchaseRefunded {
        #[key]
        listing_id: u256,
        #[key]
        buyer: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct OrderClosedDetailed {
        #[key]
        listing_id: u256,
        session_id: felt252,
        seller: ContractAddress,
        buyer: ContractAddress,
        price: u256,
        public_root: felt252,
        public_challenge: felt252,
        challenge_key: u64,
        opened_at: u64,
        settled_at: u64,
    }

    // Types moved to crate::interfaces::sessions_marketplace

    #[constructor]
    fn constructor(
        ref self: ContractState,
        pox_address: ContractAddress,
        verifier_address: ContractAddress,
        payment_token_address: ContractAddress,
        purchase_timeout_seconds: u64,
    ) {
        assert(!pox_address.is_zero(), 'Invalid KlivePox address');
        assert(!verifier_address.is_zero(), 'Invalid verifier address');
        assert(!payment_token_address.is_zero(), 'Invalid payment token');
        assert(purchase_timeout_seconds > 0, 'Invalid purchase timeout');

        self.pox.write(pox_address);
        self.verifier.write(verifier_address);
        self.payment_token.write(payment_token_address);
        self.purchase_timeout.write(purchase_timeout_seconds);
        self.listing_counter.write(0);
    }

    // Embed the IMarketplace ABI so functions are exposed as entrypoints
    #[abi(embed_v0)]
    impl MarketplaceImpl of super::IMarketplace<ContractState> {
        fn get_payment_token(self: @ContractState) -> ContractAddress { self.payment_token.read() }
        fn get_purchase_timeout(self: @ContractState) -> u64 { self.purchase_timeout.read() }
        // ============ SELLER FUNCTIONS ============

        // Crear un nuevo listing
        fn create_listing(ref self: ContractState, token_id: u256, price: u256) -> u256 {
            let caller = get_caller_address();

            // Obtener metadata desde KlivePox
            let pox = crate::interfaces::klive_pox::IKlivePoxDispatcher { contract_address: self.pox.read() };
            let meta = crate::interfaces::klive_pox::IKlivePoxDispatcherTrait::get_metadata_by_token(pox, token_id);
            let session_id = meta.session_id;
            let root = meta.root_hash;
            let session_owner = meta.author;

            // Validaciones
            assert(root != 0, 'Session not found in KlivePox');
            assert(caller == session_owner, 'Not session owner');

            // Verificar que no exista un listing para esta sesión
            let existing = self.session_to_listing.read(session_id);
            assert(existing == 0, 'Listing already exists');

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
            self.emit(ListingCreated { listing_id, seller: caller, session_id, root, price });

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

        // Abrir una compra y establecer el challenge (por buyer). Admite múltiples buyers por listing.
        fn open_purchase(ref self: ContractState, listing_id: u256, challenge: felt252, amount: u256) {
            let caller = get_caller_address();
            let mut listing = self.listings.read(listing_id);

            // Validaciones
            assert(listing.status == ListingStatus::Open, 'Listing not open');
            assert(challenge != 0, 'Invalid challenge');
            assert(caller != listing.seller, 'Seller cannot buy own listing');
            assert(amount == listing.price, 'Invalid amount');

            // Transferir fondos al escrow del contrato
            let token = crate::interfaces::erc20::IERC20Dispatcher { contract_address: self.payment_token.read() };
            let this = get_contract_address();
            let _ok = crate::interfaces::erc20::IERC20DispatcherTrait::transfer_from(token, caller, this, amount);

            // Crear orden por (listing_id, buyer)
            let order_key = (listing_id, caller);
            // evitar orden existente abierta
            assert(self.escrow_amount.read(order_key) == 0, 'Order already exists');

            let order = Order { session_id: listing.session_id, buyer: caller, challenge, amount, status: OrderStatus::Open };
            self.orders.write(order_key, order);

            // Guardar escrow y timestamp de apertura
            let now = get_block_timestamp();
            self.escrow_amount.write(order_key, amount);
            self.purchase_opened_at.write(order_key, now);

            // Emitir evento
            self.emit(PurchaseOpened { listing_id, buyer: caller, challenge, amount, opened_at: now });
        }

        // ============ PROOF SUBMISSION (On-chain) ============

        // Verificación on-chain completa
        fn settle_purchase(
            ref self: ContractState,
            listing_id: u256,
            buyer: ContractAddress,
            challenge_key: u64,
            proof: Span<felt252>,
        ) {
            let caller = get_caller_address();
            let mut listing = self.listings.read(listing_id);

            // Validaciones
            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Open, 'Listing not open');

            // Datos públicos esperados
            let session_root = listing.root;
            // Validar orden del buyer
            let order_key = (listing_id, buyer);
            let mut order = self.orders.read(order_key);
            let challenge = order.challenge;
            // Ensure numeric challenge matches order.challenge
            let expected_key: u64 = order.challenge.try_into().unwrap();
            assert(challenge_key == expected_key, 'Challenge key mismatch');
            assert(order.status == OrderStatus::Open, 'Order not open');

            // Verificar proof directamente contra el Verifier
            let verifier = IVerifierDispatcher { contract_address: self.verifier.read() };
            let result = verifier.verify_ultra_starknet_honk_proof(proof);
            let is_valid = result.is_some();

            // Emitir evento de proof
            self.emit(ProofSubmitted { listing_id, verified: is_valid });

            // Si la prueba es válida, marcar como vendido
            if is_valid {
                listing.status = ListingStatus::Sold;
                self.listings.write(listing_id, listing);

                // Marcar orden y pagar
                order.status = OrderStatus::Sold;
                self.orders.write(order_key, order);
                self.emit(Sold { listing_id, seller: listing.seller, buyer });
                // Liberar pago del escrow al seller
                let token = crate::interfaces::erc20::IERC20Dispatcher { contract_address: self.payment_token.read() };
                let amount = self.escrow_amount.read(order_key);
                if amount > 0 {
                    let _ok2 = crate::interfaces::erc20::IERC20DispatcherTrait::transfer(token, listing.seller, amount);
                }
                // Emitir evento detallado con datos públicos
                let opened_at = self.purchase_opened_at.read(order_key);
                let settled_at = get_block_timestamp();
                self.emit(OrderClosedDetailed {
                    listing_id,
                    session_id: listing.session_id,
                    seller: listing.seller,
                    buyer,
                    price: listing.price,
                    public_root: session_root,
                    public_challenge: challenge,
                    challenge_key,
                    opened_at,
                    settled_at,
                });
                // Limpiar escrow y timestamp
                self.escrow_amount.write(order_key, 0);
                self.purchase_opened_at.write(order_key, 0);
            }
        }

        // ============ REFUND FLOW (Buyer) ============

        /// Permite al comprador reclamar el saldo si el seller no responde dentro del timeout.
        fn refund_purchase(ref self: ContractState, listing_id: u256) {
            let caller = get_caller_address();
            let order_key = (listing_id, caller);
            let mut order = self.orders.read(order_key);

            assert(order.status == OrderStatus::Open, 'Not refundable');

            let opened_at = self.purchase_opened_at.read(order_key);
            let timeout = self.purchase_timeout.read();
            let now = get_block_timestamp();
            assert(now >= opened_at + timeout, 'Not expired');

            // Refund escrow
            let amount = self.escrow_amount.read(order_key);
            if amount > 0 {
                let token = crate::interfaces::erc20::IERC20Dispatcher { contract_address: self.payment_token.read() };
                let _ok = crate::interfaces::erc20::IERC20DispatcherTrait::transfer(token, caller, amount);
            }

            // Marcar orden como refundeada
            order.status = OrderStatus::Refunded;
            self.orders.write(order_key, order);

            // Clear escrow and timestamp
            self.escrow_amount.write(order_key, 0);
            self.purchase_opened_at.write(order_key, 0);

            // Evento
            self.emit(PurchaseRefunded { listing_id, buyer: caller, amount });
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

        fn get_pox_address(self: @ContractState) -> ContractAddress {
            self.pox.read()
        }

        fn get_listing_by_session(self: @ContractState, session_id: felt252) -> u256 {
            self.session_to_listing.read(session_id)
        }

        fn is_order_closed(self: @ContractState, session_id: felt252, buyer: ContractAddress) -> bool {
            let listing_id = self.session_to_listing.read(session_id);
            if listing_id == 0 { return false; }
            let order = self.orders.read((listing_id, buyer));
            order.status == OrderStatus::Sold
        }

        fn get_order(self: @ContractState, session_id: felt252, buyer: ContractAddress) -> Order {
            let listing_id = self.session_to_listing.read(session_id);
            self.orders.read((listing_id, buyer))
        }

        fn get_order_status(self: @ContractState, session_id: felt252, buyer: ContractAddress) -> OrderStatus {
            let listing_id = self.session_to_listing.read(session_id);
            let order = self.orders.read((listing_id, buyer));
            order.status
        }

        fn get_order_info(self: @ContractState, session_id: felt252, buyer: ContractAddress) -> (felt252, u256) {
            let listing_id = self.session_to_listing.read(session_id);
            let order = self.orders.read((listing_id, buyer));
            (order.challenge, order.amount)
        }
    }

    // Interface moved to crate::interfaces::sessions_marketplace
}
