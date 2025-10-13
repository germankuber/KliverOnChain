# Demo - SimpleERC20 Token

Este directorio contiene una implementación simple de un token ERC20 usando el estándar de OpenZeppelin para Cairo.

## 📋 Contenido

### Contratos Cairo
- `simple_erc20.cairo` - Implementación básica del contrato del token ERC20
- `extended_erc20.cairo` - Implementación extendida con funciones Mintable/Burnable y Ownable

### Scripts Python
- `deploy_simple_erc20.py` - Script de deployment para el token
- `interact_simple_erc20.py` - Script de ejemplo para interactuar con el token

### Documentación
- `README.md` - Este archivo

## 🔧 Características

El token `SimpleERC20` implementa:

- ✅ ERC20 completo usando OpenZeppelin Components
- ✅ Funciones estándar: `transfer`, `approve`, `transfer_from`
- ✅ Consultas: `balance_of`, `total_supply`, `allowance`
- ✅ Metadata: `name` y `symbol`
- ✅ Mint inicial en el constructor

## 🏗️ Estructura del Contrato

```cairo
#[starknet::contract]
mod SimpleERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    
    // Constructor parameters:
    // - initial_supply: u256 - Cantidad inicial de tokens
    // - recipient: ContractAddress - Dirección que recibe los tokens iniciales
    // - name: ByteArray - Nombre del token
    // - symbol: ByteArray - Símbolo del token
}
```

## 🚀 Compilación

Para compilar el contrato:

```bash
scarb build
```

## 🧪 Tests

Para ejecutar los tests:

```bash
scarb test
```

Los tests incluyen:
- ✅ Test de deployment y configuración inicial
- ✅ Test de transferencias
- ✅ Test de approve y transfer_from

## 📦 Deployment

### Opción 1: Usando el script de Python

Asegúrate de tener Katana corriendo:

```bash
katana --dev
```

Luego ejecuta el script de deployment:

```bash
python demo/deploy_simple_erc20.py
```

### Opción 2: Deployment manual con Starkli

1. **Declarar el contrato:**

```bash
starkli declare target/dev/kliver_on_chain_SimpleERC20.contract_class.json \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json
```

2. **Deployar el contrato:**

```bash
# Parámetros del constructor:
# - initial_supply (u256 low, high)
# - recipient (address)
# - name (ByteArray)
# - symbol (ByteArray)

starkli deploy <CLASS_HASH> \
  1000000000000000000000000 0 \  # initial_supply: 1M tokens
  <RECIPIENT_ADDRESS> \
  str:"Kliver Demo Token" \
  str:"KDEMO" \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json
```

## 🔍 Interacción con el Contrato

### Consultar el balance

```bash
starkli call <CONTRACT_ADDRESS> balance_of <ADDRESS>
```

### Transferir tokens

```bash
starkli invoke <CONTRACT_ADDRESS> transfer <RECIPIENT> <AMOUNT_LOW> <AMOUNT_HIGH> \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json
```

### Aprobar gasto

```bash
starkli invoke <CONTRACT_ADDRESS> approve <SPENDER> <AMOUNT_LOW> <AMOUNT_HIGH> \
  --account ~/.starkli-wallets/deployer/account.json \
  --keystore ~/.starkli-wallets/deployer/keystore.json
```

## 📚 Recursos

- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts)
- [Starknet Documentation](https://docs.starknet.io)
- [Cairo Book](https://book.cairo-lang.org)

## 💡 Ejemplo de Uso en Python

Para ver un ejemplo completo de cómo interactuar con el token, ejecuta:

```bash
python demo/interact_simple_erc20.py
```

O usa el siguiente código de ejemplo:

```python
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account

# Conectar al contrato
contract = Contract(
    address="<CONTRACT_ADDRESS>",
    abi=contract_abi,
    provider=account,
)

# Leer balance
balance = await contract.functions["balance_of"].call(address)
print(f"Balance: {balance.balance}")

# Transferir tokens
transfer_result = await contract.functions["transfer"].invoke(
    recipient_address,
    amount,
    max_fee=int(1e16)
)
await transfer_result.wait_for_acceptance()
```

## 🚀 ExtendedERC20 - Token con Características Adicionales

El token `ExtendedERC20` incluye funcionalidades adicionales:

### Características Extra:
- ✅ **Mintable**: El owner puede crear nuevos tokens
- ✅ **Burnable**: Los usuarios pueden quemar sus propios tokens
- ✅ **Ownable**: Control de acceso con owner

### Funciones Adicionales:

```cairo
// Mint nuevos tokens (solo owner)
fn mint(recipient: ContractAddress, amount: u256)

// Quemar tokens propios
fn burn(amount: u256)
```

### Ejemplo de Deployment:

```bash
# Constructor parameters:
# - initial_supply (u256)
# - recipient (address)
# - name (ByteArray)
# - symbol (ByteArray)  
# - owner (address)

starkli deploy <CLASS_HASH> \
  1000000000000000000000000 0 \
  <RECIPIENT_ADDRESS> \
  str:"Extended Token" \
  str:"EXTK" \
  <OWNER_ADDRESS>
```

## 🎯 Casos de Uso

Este token puede ser usado para:

- 🏦 Token de utilidad en aplicaciones
- 💰 Sistema de puntos o recompensas
- 🎮 Moneda dentro de juegos
- 🧪 Testing y desarrollo
- 📚 Aprendizaje y demostración

## ⚠️ Notas Importantes

- Este es un contrato de demostración para fines educativos
- Para producción, considera agregar:
  - Mintable/Burnable capabilities
  - Access control (Ownable)
  - Pausable functionality
  - Snapshots para voting
  - Rate limiting
- Siempre audita los contratos antes de deployar en mainnet
