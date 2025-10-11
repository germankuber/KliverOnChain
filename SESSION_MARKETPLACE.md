# Session Marketplace

Contrato de marketplace para compra/venta de sesiones de simulación en Starknet.

## Descripción

El `SessionMarketplace` es un contrato inteligente que permite a los usuarios publicar y vender sesiones de simulación. Funciona como un marketplace descentralizado donde los vendedores (sellers) pueden listar sus sesiones y los compradores (buyers) pueden adquirirlas.

## Características

### 1. Publicar Sesión (`publish_session`)

Permite a un usuario publicar una sesión para la venta.

**Parámetros:**
- `simulation_id`: ID de la simulación
- `session_id`: ID único de la sesión
- `root_hash`: Hash raíz de la sesión
- `score`: Puntuación de la sesión
- `price`: Precio de venta (debe ser > 0)

**Validaciones:**
- La sesión no debe existir previamente
- El precio debe ser mayor a 0

**Evento emitido:** `SessionPublished`

### 2. Comprar Sesión (`purchase_session`)

Permite a un usuario comprar una sesión publicada.

**Parámetros:**
- `session_id`: ID de la sesión a comprar

**Validaciones:**
- La sesión debe existir
- La sesión debe estar disponible (no vendida ni cancelada)
- El comprador no puede ser el vendedor

**Evento emitido:** `SessionPurchased`

**Nota:** La transferencia de fondos debe implementarse externamente (integración con ERC20).

---

## Extensión avanzada: Órdenes de compra (SessionsMarketplace)

Además del contrato simple `session_marketplace.cairo`, existe una variante avanzada `sessions_marketplace.cairo` que implementa un flujo de órdenes de compra con escrow y verificación mediante challenge y pruebas.

### Resumen del flujo

1. El vendedor crea un listing a partir de una sesión registrada en el Registry (se valida propiedad y `root`).
2. El comprador abre una orden de compra indicando `listing_id`, `challenge` y enviando el `amount` exacto (precio) al contrato vía `ERC20.transfer_from` (escrow on‑chain).
3. El contrato guarda `buyer`, `challenge`, `escrow_amount` y `opened_at` (timestamp de la orden).
4. El vendedor completa la venta enviando una prueba válida y public inputs que incluyen `root` y `challenge`.
5. Si la prueba es válida, el contrato marca `Sold` y libera el escrow al seller.
6. Si el seller no responde dentro de un `purchase_timeout` (config del contrato), el buyer puede pedir reembolso y la orden se cancela volviendo a `Open`.

### Constructor (SessionsMarketplace)

```text
constructor(
  registry_address: ContractAddress,
  verifier_address: ContractAddress,
  payment_token_address: ContractAddress,
  purchase_timeout_seconds: u64
)
```

- `payment_token`: ERC20 utilizado para escrow.
- `purchase_timeout`: ventana de tiempo tras la cual el buyer puede reclamar reembolso.

### Funciones nuevas/extendidas

- `open_purchase(listing_id: u256, challenge: felt252, amount: u256)`
  - Requiere `status == Open`, `amount == price`, `challenge != 0`, caller ≠ seller.
  - Transfiere `amount` desde el buyer al contrato (`transfer_from`).
  - Guarda `escrow_amount[listing_id]` y `purchase_opened_at[listing_id] = block_timestamp`.
  - Evento: `PurchaseOpened { listing_id, buyer, challenge, amount, opened_at }`.

- `submit_proof_and_verify(listing_id: u256, proof: Span<felt252>, public_inputs: Span<felt252>)`
  - Valida que `public_inputs[0]` sea `root` y `public_inputs[1]` sea el `challenge` del listing.
  - Si la verificación es válida: `status = Sold`, emite `Sold` y transfiere el escrow al seller.

- `refund_purchase(listing_id: u256)`
  - Solo buyer, con `status == Purchased`.
  - Requiere `now >= opened_at + purchase_timeout`.
  - Devuelve escrow al buyer, limpia estado y vuelve a `Open`.
- Evento: `PurchaseRefunded { listing_id, buyer, amount }`.

### Consultas de orden

- `is_order_closed(session_id: felt252, buyer: ContractAddress) -> bool`
  - Retorna true si la orden para ese `buyer` quedó en estado `Sold`.

- `get_order(session_id: felt252, buyer: ContractAddress) -> Order`
  - Retorna la metadata completa de la orden, incluyendo `challenge`, `amount` y `status`.

- `get_order_status(session_id: felt252, buyer: ContractAddress) -> OrderStatus`
  - Retorna el estado de la orden (Open, Sold, Refunded).

- `get_order_info(session_id: felt252, buyer: ContractAddress) -> (challenge: felt252, amount: u256)`
  - Retorna los datos mínimos de la orden para UIs off-chain sin deserializar structs.

### Eventos

```text
PurchaseOpened { listing_id, buyer, challenge, amount, opened_at }
PurchaseRefunded { listing_id, buyer, amount }
```

### Notas de integración

- El buyer debe ejecutar `ERC20.approve(marketplace, price)` antes de `open_purchase`.
- El contrato mantiene compatibilidad con el flujo de verificación por `challenge` + `root` y un `IVerifier`.
- El `payment_token` y `purchase_timeout` se pueden consultar con `get_payment_token()` y `get_purchase_timeout()`.


### 3. Obtener Sesiones por Simulación (`get_sessions_by_simulation`)

Devuelve todas las sesiones activas de una simulación específica.

**Parámetros:**
- `simulation_id`: ID de la simulación

**Retorna:** `Array<SessionListing>` - Lista de sesiones

### 4. Cancelar Sesión (`remove_session`)

Permite al vendedor cancelar una sesión antes de que sea vendida.

**Parámetros:**
- `session_id`: ID de la sesión a cancelar

**Validaciones:**
- Solo el vendedor puede cancelar
- La sesión debe estar disponible (no vendida)

**Evento emitido:** `SessionCancelled`

### 5. Funciones de Consulta

- `get_session(session_id)`: Obtiene los detalles de una sesión
- `session_exists(session_id)`: Verifica si una sesión existe
- `is_available(session_id)`: Verifica si una sesión está disponible para compra

## Estructura de Datos

### SessionListing

```cairo
struct SessionListing {
    session_id: felt252,
    simulation_id: felt252,
    root_hash: felt252,
    score: u128,
    price: u128,
    seller: ContractAddress,
    buyer: ContractAddress,
    status: ListingStatus,
}
```

### ListingStatus

```cairo
enum ListingStatus {
    Available,  // Disponible para compra
    Sold,       // Vendida
    Cancelled,  // Cancelada por el vendedor
}
```

## Eventos

### SessionPublished
```cairo
struct SessionPublished {
    session_id: felt252,
    simulation_id: felt252,
    seller: ContractAddress,
    root_hash: felt252,
    score: u128,
    price: u128,
}
```

### SessionPurchased
```cairo
struct SessionPurchased {
    session_id: felt252,
    seller: ContractAddress,
    buyer: ContractAddress,
    price: u128,
}
```

### SessionCancelled
```cairo
struct SessionCancelled {
    session_id: felt252,
    seller: ContractAddress,
}
```

## Flujo de Uso

1. **Vendedor publica sesión:**
   ```cairo
   marketplace.publish_session(sim_id, session_id, root, score, price);
   ```

2. **Comprador busca sesiones:**
   ```cairo
   let sessions = marketplace.get_sessions_by_simulation(sim_id);
   ```

3. **Comprador verifica disponibilidad:**
   ```cairo
   let available = marketplace.is_available(session_id);
   ```

4. **Comprador compra sesión:**
   ```cairo
   marketplace.purchase_session(session_id);
   ```

5. **Vendedor puede cancelar (si no fue vendida):**
   ```cairo
   marketplace.remove_session(session_id);
   ```

## Integraciones Futuras

- **Pagos:** Integración con contratos ERC20 para manejar transferencias de fondos
- **Escrow:** Sistema de escrow para garantizar transacciones seguras
- **Comisiones:** Sistema de comisiones para el marketplace
- **Subastas:** Funcionalidad de subastas para sesiones premium

## Tests

El contrato incluye 14 tests que cubren:
- ✅ Publicación de sesiones
- ✅ Compra de sesiones
- ✅ Cancelación de listados
- ✅ Validaciones de permisos
- ✅ Múltiples simulaciones
- ✅ Estados de disponibilidad
- ✅ Casos de error

Ejecutar tests:
```bash
snforge test test_session_marketplace
```

## Archivos

- **Contrato:** `src/session_marketplace.cairo`
- **Tests:** `tests/test_session_marketplace.cairo`
- **Interface:** Exportada en `src/lib.cairo`

## Diferencias con session_escrow.cairo

El `session_marketplace.cairo` es la versión completa del marketplace con:
- Estado de compra/venta (`ListingStatus`)
- Campo `buyer` para rastrear compradores
- Función `purchase_session` para compras
- Validación de disponibilidad
- Eventos más completos

El `session_escrow.cairo` es más simple y solo maneja publicación/eliminación sin lógica de compra.
