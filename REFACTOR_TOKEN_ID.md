# Refactorización: Sessions Marketplace - Uso de token_id

## Resumen de Cambios

Se refactorizó el contrato `SessionsMarketplace` para usar `token_id` como identificador principal en lugar de `listing_id`, manteniendo el historial completo de listings.

## Cambios Principales

### 1. Storage Actualizado

**Antes:**
```cairo
session_to_listing: Map<felt252, u256>  // session_id -> listing_id
```

**Ahora:**
```cairo
active_listing: Map<u256, u256>                    // token_id -> listing_id activo
token_listing_history: Map<(u256, u256), u256>    // (token_id, index) -> listing_id
token_listing_count: Map<u256, u256>              // token_id -> cantidad de listings
```

### 2. Interfaz IMarketplace

Todas las funciones principales ahora usan `token_id` en lugar de `listing_id`:

- `create_listing(token_id, price)` - ya no retorna el listing_id
- `close_listing(token_id)` - cierra el listing activo del token
- `open_purchase(token_id, challenge, amount)` - abre compra usando token_id
- `settle_purchase(token_id, buyer, challenge_key, proof)` - liquida usando token_id
- `refund_purchase(token_id)` - reembolsa usando token_id

### 3. Nuevas Funciones de Historial

```cairo
// Obtener cantidad de listings históricos de un token
fn get_token_listing_count(token_id: u256) -> u256

// Obtener listing_id en un índice específico del historial
fn get_listing_id_at_index(token_id: u256, index: u256) -> u256

// Obtener el listing_id activo actual
fn get_active_listing_id(token_id: u256) -> u256

// Obtener listing por su listing_id (para consultar historial)
fn get_listing_by_id(listing_id: u256) -> Listing
```

### 4. Funciones de Vista Actualizadas

Todas las funciones de orden ahora usan `token_id`:

```cairo
fn get_listing(token_id: u256) -> Listing
fn get_listing_status(token_id: u256) -> ListingStatus
fn is_order_closed(token_id: u256, buyer: ContractAddress) -> bool
fn get_order(token_id: u256, buyer: ContractAddress) -> Order
fn get_order_status(token_id: u256, buyer: ContractAddress) -> OrderStatus
fn get_order_info(token_id: u256, buyer: ContractAddress) -> (felt252, u256)
```

### 5. Eventos Actualizados

Todos los eventos ahora incluyen `token_id` como campo indexado:

```cairo
struct ListingCreated {
    #[key] token_id: u256,
    #[key] listing_id: u256,
    ...
}

struct PurchaseOpened {
    #[key] token_id: u256,
    #[key] listing_id: u256,
    ...
}

// Similar para: ProofSubmitted, Sold, ListingCancelled, PurchaseRefunded
```

## Beneficios

1. **API más intuitiva**: Los usuarios interactúan directamente con `token_id` del NFT
2. **Historial completo**: Se mantiene registro de todos los listings por token
3. **Eventos mejores**: Filtrado más fácil por `token_id` en eventos
4. **Un solo listing activo**: Garantizado por diseño a nivel de storage
5. **Menos confusión**: No necesitas buscar el `listing_id` para operar

## Ejemplo de Uso

### Crear y gestionar listing:
```cairo
// Crear listing (antes retornaba listing_id, ahora es void)
marketplace.create_listing(token_id: 123, price: 1000);

// Consultar listing activo
let listing = marketplace.get_listing(token_id: 123);

// Cerrar listing
marketplace.close_listing(token_id: 123);
```

### Consultar historial:
```cairo
// Obtener cantidad de listings históricos
let count = marketplace.get_token_listing_count(token_id: 123);

// Iterar sobre historial
let mut i = 0;
while i < count {
    let listing_id = marketplace.get_listing_id_at_index(token_id: 123, index: i);
    let listing = marketplace.get_listing_by_id(listing_id);
    // procesar listing histórico...
    i += 1;
}
```

### Comprar:
```cairo
// Abrir compra (usa token_id directamente)
marketplace.open_purchase(token_id: 123, challenge, amount);

// Seller liquida la compra
marketplace.settle_purchase(token_id: 123, buyer, challenge_key, proof);

// O buyer pide reembolso
marketplace.refund_purchase(token_id: 123);
```

## Compatibilidad

**⚠️ Breaking Changes:**
- Todas las funciones externas ahora usan `token_id` en lugar de `listing_id`
- `create_listing` ya no retorna `listing_id`
- Función `get_listing_by_session` fue removida
- Función `get_order_status_by_listing` fue removida

**Migración requerida:**
- Actualizar todos los contratos e interfaces que llaman al marketplace
- Actualizar el frontend para usar `token_id` en lugar de `listing_id`
- Actualizar listeners de eventos para usar el nuevo formato

## Validación de "Un Solo Listing Activo"

El contrato garantiza que solo puede haber un listing activo por `token_id`:

```cairo
// En create_listing:
let existing_listing_id = self.active_listing.read(token_id);
assert(existing_listing_id == 0, 'Active listing exists');
```

Cuando se cierra un listing, se libera el slot:
```cairo
// En close_listing:
self.active_listing.write(token_id, 0);
```

Esto permite re-listar el mismo token en el futuro, pero nunca tener dos listings activos simultáneamente.
