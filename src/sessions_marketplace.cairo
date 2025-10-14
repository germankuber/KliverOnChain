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
    use super::super::interfaces::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait};
    // Bring marketplace types into scope
    use crate::interfaces::marketplace_interface::{Listing, Order, ListingStatus, OrderStatus};
    // Registry used for proof verification
    // Types and dispatcher re-exported at file scope

    // use dispatcher imported at module level

    // Types moved to crate::interfaces::sessions_marketplace

    #[storage]
    struct Storage {
        // Owner del contrato
        owner: ContractAddress,
        // Direcciones de los contratos
        pox: ContractAddress,
        registry: ContractAddress,
        // Token de pago (ERC20) y timeout de compra (en segundos)
        payment_token: ContractAddress,
        purchase_timeout: u64,
        // Gestión de listings - historial completo
        listings: Map<u256, Listing>, // listing_id -> Listing
        listing_counter: u256,
        // Mapeo de token_id al listing_id activo actual (0 = no activo)
        active_listing: Map<u256, u256>, // token_id -> listing_id
        // Historial: lista de todos los listing_ids por token_id
        token_listing_history: Map<(u256, u256), u256>, // (token_id, index) -> listing_id
        token_listing_count: Map<u256, u256>, // token_id -> cantidad de listings históricos
        // Mapeo auxiliar para rastrear órdenes abiertas por (token_id, buyer) -> listing_id
        buyer_active_order: Map<(u256, ContractAddress), u256>, // (token_id, buyer) -> listing_id
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
        token_id: u256,
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
        token_id: u256,
        #[key]
        listing_id: u256,
        #[key]
        buyer: ContractAddress,
        challenge: u64,
        amount: u256,
        opened_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProofSubmitted {
        #[key]
        token_id: u256,
        #[key]
        listing_id: u256,
        verified: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct Sold {
        #[key]
        token_id: u256,
        #[key]
        listing_id: u256,
        seller: ContractAddress,
        buyer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ListingCancelled {
        #[key]
        token_id: u256,
        #[key]
        listing_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PurchaseRefunded {
        #[key]
        token_id: u256,
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
        challenge: u64,
        opened_at: u64,
        settled_at: u64,
    }

    // Types moved to crate::interfaces::sessions_marketplace

    #[constructor]
    fn constructor(
        ref self: ContractState,
        pox_address: ContractAddress,
        registry_address: ContractAddress,
        payment_token_address: ContractAddress,
        purchase_timeout_seconds: u64,
    ) {
        assert(!pox_address.is_zero(), 'Invalid KliverPox address');
        assert(!registry_address.is_zero(), 'Invalid registry address');
        assert(!payment_token_address.is_zero(), 'Invalid payment token');
        assert(purchase_timeout_seconds > 0, 'Invalid purchase timeout');

        self.owner.write(get_caller_address());
        self.pox.write(pox_address);
        self.registry.write(registry_address);
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
        fn create_listing(ref self: ContractState, token_id: u256, price: u256) {
            let caller = get_caller_address();

            // Obtener metadata desde KliverPox
            let pox = crate::interfaces::kliver_pox::IKliverPoxDispatcher { contract_address: self.pox.read() };
            let meta = crate::interfaces::kliver_pox::IKliverPoxDispatcherTrait::get_metadata_by_token(pox, token_id);
            let session_id = meta.session_id;
            let root = meta.root_hash;
            let session_owner = meta.author;

            // Validaciones
            assert(root != 0, 'Session not found in KliverPox');
            assert(caller == session_owner, 'Not session owner');

            // Verificar que no exista un listing activo para este token_id
            let existing_listing_id = self.active_listing.read(token_id);
            assert(existing_listing_id == 0, 'Active listing exists');

            // Validar precio positivo
            assert(price > 0, 'Price must be positive');

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
            
            // Establecer como listing activo
            self.active_listing.write(token_id, listing_id);
            
            // Agregar al historial
            let history_count = self.token_listing_count.read(token_id);
            self.token_listing_history.write((token_id, history_count), listing_id);
            self.token_listing_count.write(token_id, history_count + 1);

            // Emitir evento
            self.emit(ListingCreated { token_id, listing_id, seller: caller, session_id, root, price });
        }

        // Cerrar un listing (solo seller). Permite re-listar el mismo token más tarde.
        fn close_listing(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let listing_id = self.active_listing.read(token_id);
            
            assert(listing_id != 0, 'No active listing');
            
            let mut listing = self.listings.read(listing_id);

            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Open, 'Cannot close');

            listing.status = ListingStatus::Closed;
            self.listings.write(listing_id, listing);
            
            // Liberar el token_id para permitir nuevo listing a futuro
            self.active_listing.write(token_id, 0);

            self.emit(ListingCancelled { token_id, listing_id });
        }

        // ============ BUYER FUNCTIONS ============

        // Abrir una compra y establecer el challenge (por buyer). Admite múltiples buyers por listing.
        fn open_purchase(ref self: ContractState, token_id: u256, challenge: u64, amount: u256) {
            let caller = get_caller_address();

            // Obtener el listing activo del token
            let listing_id = self.active_listing.read(token_id);
            assert(listing_id != 0, 'No active listing');

            let mut listing = self.listings.read(listing_id);

            // Validaciones
            assert(listing.status == ListingStatus::Open, 'Listing not open');
            assert(challenge >= 1000000000_u64, 'Invalid challenge');
            assert(challenge <= 9999999999_u64, 'Invalid challenge');
            assert(caller != listing.seller, 'Seller cannot buy own listing');
            assert(amount == listing.price, 'Invalid amount');

            // Transferir fondos al escrow del contrato
            let token = crate::interfaces::erc20::IERC20Dispatcher { contract_address: self.payment_token.read() };
            let this = get_contract_address();
            let _ok = crate::interfaces::erc20::IERC20DispatcherTrait::transfer_from(token, caller, this, amount);
            assert(_ok, 'Transfer failed');

            // Crear orden por (listing_id, buyer)
            let order_key = (listing_id, caller);
            // evitar orden existente abierta
            assert(self.escrow_amount.read(order_key) == 0, 'Order already exists');

            // Limpiar cualquier orden previa del buyer para este token (si existía)
            let prev_listing_id = self.buyer_active_order.read((token_id, caller));
            if prev_listing_id != 0 && prev_listing_id != listing_id {
                // Buyer tenía una orden en un listing previo, la limpiamos
                self.buyer_active_order.write((token_id, caller), 0);
            }

            let order = Order { session_id: listing.session_id, buyer: caller, challenge, amount, status: OrderStatus::Open };
            self.orders.write(order_key, order);

            // Guardar escrow y timestamp de apertura
            let now = get_block_timestamp();
            self.escrow_amount.write(order_key, amount);
            self.purchase_opened_at.write(order_key, now);
            
            // Registrar orden activa del buyer para este token
            self.buyer_active_order.write((token_id, caller), listing_id);

            // Emitir evento
            self.emit(PurchaseOpened { token_id, listing_id, buyer: caller, challenge, amount, opened_at: now });
        }

        // ============ PROOF SUBMISSION (On-chain) ============

        // Verificación on-chain completa
        fn settle_purchase(
            ref self: ContractState,
            token_id: u256,
            buyer: ContractAddress,
            challenge: u64,
            proof: Span<felt252>,
        ) {
            let caller = get_caller_address();

            // Obtener el listing activo del token
            let listing_id = self.active_listing.read(token_id);
            assert(listing_id != 0, 'No active listing');

            let mut listing = self.listings.read(listing_id);

            // Validaciones
            assert(listing.seller == caller, 'Not the seller');
            assert(listing.status == ListingStatus::Open, 'Listing not open');

            // Datos públicos esperados
            let session_root = listing.root;
            // Validar orden del buyer
            let order_key = (listing_id, buyer);
            let mut order = self.orders.read(order_key);
            // Verify challenge matches the one in the order
            assert(challenge == order.challenge, 'Challenge mismatch');
            assert(order.status == OrderStatus::Open, 'Order not open');

            // Verificar proof contra el Registry
            let registry = ISessionRegistryDispatcher { contract_address: self.registry.read() };
            let result = registry.verify_proof(proof, session_root, challenge);
            let is_valid = result.is_some();

            // Emitir evento de proof
            self.emit(ProofSubmitted { token_id, listing_id, verified: is_valid });

            // Si la prueba es válida, liquidar la orden (el listing permanece Open)
            if is_valid {
                // Marcar orden y pagar
                order.status = OrderStatus::Settled;
                self.orders.write(order_key, order);
                self.emit(Sold { token_id, listing_id, seller: listing.seller, buyer });
                // Liberar pago del escrow al seller
                let token = crate::interfaces::erc20::IERC20Dispatcher { contract_address: self.payment_token.read() };
                let amount = self.escrow_amount.read(order_key);
                if amount > 0 {
                    let _ok2 = crate::interfaces::erc20::IERC20DispatcherTrait::transfer(token, listing.seller, amount);
                    assert(_ok2, 'Transfer failed');
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
                    challenge,
                    opened_at,
                    settled_at,
                });
                // Limpiar escrow y timestamp (mantenemos buyer_active_order para consultas históricas)
                self.escrow_amount.write(order_key, 0);
                self.purchase_opened_at.write(order_key, 0);
            }
        }

        // ============ REFUND FLOW (Buyer) ============

        /// Permite al comprador reclamar el saldo si el seller no responde dentro del timeout.
        fn refund_purchase(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            
            // Buscar el listing_id de la orden activa del buyer
            let listing_id = self.buyer_active_order.read((token_id, caller));
            assert(listing_id != 0, 'No order for this buyer');
            
            let order_key = (listing_id, caller);
            let mut order = self.orders.read(order_key);

            assert(order.status == OrderStatus::Open, 'Not refundable');

            let opened_at = self.purchase_opened_at.read(order_key);
            let timeout = self.purchase_timeout.read();
            let now = get_block_timestamp();
            // Permitir refund si expiró o si el listing está Closed
            let listing = self.listings.read(listing_id);
            let is_closed = listing.status == ListingStatus::Closed;
            let is_expired = now >= opened_at + timeout;
            assert(is_closed || is_expired, 'Cannot refund yet');

            // Refund escrow
            let amount = self.escrow_amount.read(order_key);
            if amount > 0 {
                let token = crate::interfaces::erc20::IERC20Dispatcher { contract_address: self.payment_token.read() };
                let _ok = crate::interfaces::erc20::IERC20DispatcherTrait::transfer(token, caller, amount);
                assert(_ok, 'Transfer failed');
            }

            // Marcar orden como refundeada
            order.status = OrderStatus::Refunded;
            self.orders.write(order_key, order);

            // Clear escrow y timestamp (mantenemos buyer_active_order para consultas históricas)
            self.escrow_amount.write(order_key, 0);
            self.purchase_opened_at.write(order_key, 0);

            // Evento
            self.emit(PurchaseRefunded { token_id, listing_id, buyer: caller, amount });
        }

        // ============ VIEW FUNCTIONS ============
        
        // Listing functions - obtener listing activo por token_id
        fn get_listing(self: @ContractState, token_id: u256) -> Listing {
            let listing_id = self.active_listing.read(token_id);
            if listing_id == 0 {
                // No hay listing activo, buscar el último en el historial
                let history_count = self.token_listing_count.read(token_id);
                assert(history_count > 0, 'No listing exists');
                let last_listing_id = self.token_listing_history.read((token_id, history_count - 1));
                return self.listings.read(last_listing_id);
            }
            self.listings.read(listing_id)
        }

        fn get_listing_status(self: @ContractState, token_id: u256) -> ListingStatus {
            let listing_id = self.active_listing.read(token_id);
            if listing_id == 0 {
                // No hay listing activo, buscar el último en el historial
                let history_count = self.token_listing_count.read(token_id);
                if history_count == 0 {
                    // Nunca ha habido un listing, retornar Closed por defecto
                    return ListingStatus::Closed;
                }
                let last_listing_id = self.token_listing_history.read((token_id, history_count - 1));
                let listing = self.listings.read(last_listing_id);
                return listing.status;
            }
            let listing = self.listings.read(listing_id);
            listing.status
        }

        fn get_listing_count(self: @ContractState) -> u256 {
            self.listing_counter.read()
        }

        fn get_pox_address(self: @ContractState) -> ContractAddress {
            self.pox.read()
        }

        fn get_registry_address(self: @ContractState) -> ContractAddress {
            self.registry.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn set_registry_address(ref self: ContractState, new_registry: ContractAddress) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Only owner can set registry');
            assert(!new_registry.is_zero(), 'Invalid registry address');
            self.registry.write(new_registry);
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Only owner can transfer');
            assert(!new_owner.is_zero(), 'Invalid new owner address');
            self.owner.write(new_owner);
        }

        // History functions - nuevas funciones para consultar historial
        fn get_token_listing_count(self: @ContractState, token_id: u256) -> u256 {
            self.token_listing_count.read(token_id)
        }

        fn get_listing_id_at_index(self: @ContractState, token_id: u256, index: u256) -> u256 {
            self.token_listing_history.read((token_id, index))
        }

        fn get_active_listing_id(self: @ContractState, token_id: u256) -> u256 {
            self.active_listing.read(token_id)
        }

        fn get_listing_by_id(self: @ContractState, listing_id: u256) -> Listing {
            self.listings.read(listing_id)
        }

        // Order functions - actualizadas para usar token_id
        fn is_order_closed(self: @ContractState, token_id: u256, buyer: ContractAddress) -> bool {
            let listing_id = self.buyer_active_order.read((token_id, buyer));
            if listing_id == 0 { return false; }
            let order = self.orders.read((listing_id, buyer));
            order.status == OrderStatus::Settled
        }

        fn get_order(self: @ContractState, token_id: u256, buyer: ContractAddress) -> Order {
            let listing_id = self.buyer_active_order.read((token_id, buyer));
            self.orders.read((listing_id, buyer))
        }

        fn get_order_status(self: @ContractState, token_id: u256, buyer: ContractAddress) -> OrderStatus {
            let listing_id = self.buyer_active_order.read((token_id, buyer));
            let order = self.orders.read((listing_id, buyer));
            order.status
        }

        fn get_order_info(self: @ContractState, token_id: u256, buyer: ContractAddress) -> (u64, u256) {
            let listing_id = self.buyer_active_order.read((token_id, buyer));
            let order = self.orders.read((listing_id, buyer));
            (order.challenge, order.amount)
        }
    }

    // Interface moved to crate::interfaces::sessions_marketplace
}
