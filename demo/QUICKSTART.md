# 🚀 Guía Rápida - Token ERC20

## ⚡ Inicio Rápido (5 minutos)

### 1. Compilar el Proyecto
```bash
scarb build
```

### 2. Ejecutar Tests
```bash
scarb test test_simple_erc20
```

### 3. Deployar en Katana (Local)

**Terminal 1 - Iniciar Katana:**
```bash
katana --dev
```

**Terminal 2 - Deployar el Token:**
```bash
python demo/deploy_simple_erc20.py
```

### 4. Interactuar con el Token
```bash
python demo/interact_simple_erc20.py
```

## 📝 Archivos Principales

| Archivo | Descripción |
|---------|-------------|
| `src/demo/simple_erc20.cairo` | Contrato ERC20 básico |
| `src/demo/extended_erc20.cairo` | Contrato ERC20 con mint/burn |
| `tests/test_simple_erc20.cairo` | Tests del token |
| `demo/deploy_simple_erc20.py` | Script de deployment |
| `demo/interact_simple_erc20.py` | Script de interacción |
| `demo/README.md` | Documentación completa |
| `demo/RESUMEN.md` | Resumen de implementación |

## 🎯 Características Implementadas

### SimpleERC20 (Básico)
- ✅ Transfer
- ✅ Approve
- ✅ TransferFrom
- ✅ Balance queries
- ✅ Metadata (name, symbol, decimals)

### ExtendedERC20 (Avanzado)
- ✅ Todo lo del SimpleERC20
- ✅ Mint (solo owner)
- ✅ Burn
- ✅ Ownable (control de acceso)

## 🧪 Tests

```bash
# Ejecutar solo los tests del ERC20
scarb test test_simple_erc20

# Ejecutar todos los tests
scarb test
```

**Resultado esperado:**
```
Tests: 3 passed, 0 failed, 0 ignored
```

## 📦 Deployment

### Opción 1: Script Python (Recomendado)
```bash
# Asegúrate de que Katana esté corriendo
python demo/deploy_simple_erc20.py
```

El script:
1. Declara el contrato
2. Lo deploya con parámetros por defecto
3. Verifica el deployment
4. Guarda la info en `deploy/deployment_simple_erc20.json`

### Opción 2: Starkli (Manual)
```bash
# 1. Declarar
starkli declare target/dev/kliver_on_chain_SimpleERC20.contract_class.json

# 2. Deployar
starkli deploy <CLASS_HASH> \
  1000000000000000000000000 0 \
  <RECIPIENT_ADDRESS> \
  str:"Mi Token" \
  str:"MTK"
```

## 🔗 Interacción

### Usando el Script
```bash
python demo/interact_simple_erc20.py
```

Este script demuestra:
- Consultar información del token
- Verificar balances
- Transferir tokens
- Aprobar allowances
- Usar transferFrom

### Usando Starkli
```bash
# Ver balance
starkli call <CONTRACT> balance_of <ADDRESS>

# Transferir tokens
starkli invoke <CONTRACT> transfer <RECIPIENT> <AMOUNT_LOW> <AMOUNT_HIGH>

# Aprobar
starkli invoke <CONTRACT> approve <SPENDER> <AMOUNT_LOW> <AMOUNT_HIGH>
```

## 🆘 Troubleshooting

### Error: "RPC connection failed"
**Solución:** Asegúrate de que Katana esté corriendo
```bash
katana --dev
```

### Error: "Module not found"
**Solución:** Instala las dependencias de Python
```bash
pip install starknet-py
```

### Error: "Contract not found"
**Solución:** Asegúrate de compilar primero
```bash
scarb build
```

## 📚 Documentación Adicional

- **README completo:** `demo/README.md`
- **Resumen técnico:** `demo/RESUMEN.md`
- **OpenZeppelin Docs:** https://docs.openzeppelin.com/contracts-cairo
- **Starknet Docs:** https://docs.starknet.io

## 🎓 Próximos Pasos

1. **Experimentar:** Modifica los parámetros en los scripts
2. **Extender:** Agrega nuevas funcionalidades al ExtendedERC20
3. **Integrar:** Usa el token en tus propios contratos
4. **Deployar:** Lleva el token a testnet o mainnet

## 💡 Tips

- Los decimales por defecto son 18 (como ETH)
- Los u256 en Cairo son bajos/altos (low/high)
- Usa el ExtendedERC20 si necesitas mint/burn
- Revisa el archivo de deployment para las direcciones

---

**¿Necesitas ayuda?** Revisa el `README.md` completo en la carpeta demo.
