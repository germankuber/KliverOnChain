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
