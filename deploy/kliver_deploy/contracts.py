"""
Contract classes for Kliver deployment system.
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from .utils import StarknetUtils, Colors
from .config import ContractConfig


class BaseContract(ABC):
    """Base class for all Kliver contracts."""
    
    def __init__(self, contract_name: str, class_name: str):
        self.contract_name = contract_name
        self.class_name = class_name
    
    @abstractmethod
    def get_constructor_calldata(self, owner_address: str, **kwargs) -> List[str]:
        """Get constructor calldata for the contract."""
        pass
    
    @abstractmethod
    def validate_dependencies(self, **kwargs) -> bool:
        """Validate that all required dependencies are provided."""
        pass
    
    def get_dependency_info(self, **kwargs) -> List[str]:
        """Get human-readable dependency information."""
        return []


class KliverNFT(BaseContract):
    """Kliver NFT (ERC721) contract."""
    
    def __init__(self):
        super().__init__("KliverNFT", "KliverNFT")
    
    def get_constructor_calldata(self, owner_address: str, base_uri: str = "", **kwargs) -> List[str]:
        """NFT requires: owner + base_uri (ByteArray)"""
        if base_uri:
            print(f"{Colors.INFO}📋 Using base URI: {base_uri}{Colors.RESET}")
            base_uri_calldata = StarknetUtils.string_to_bytearray_calldata(base_uri)
        else:
            print(f"{Colors.WARNING}⚠️  No base_uri provided, using empty ByteArray{Colors.RESET}")
            base_uri_calldata = ["0", "0", "0"]
        
        return [owner_address] + base_uri_calldata
    
    def validate_dependencies(self, **kwargs) -> bool:
        """NFT has no dependencies."""
        return True


class KliverRegistry(BaseContract):
    """Kliver Registry contract."""

    def __init__(self):
        super().__init__("kliver_registry", "KliverRegistry")

    def get_constructor_calldata(self, owner_address: str, nft_address: str,
                               token_simulation_address: str, verifier_address: str = "0x0", **kwargs) -> List[str]:
        """Registry requires: owner + nft_address + token_simulation_address + verifier_address"""
        print(f"{Colors.INFO}📋 Using NFT address: {nft_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using TokenSimulation address: {token_simulation_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using Verifier address: {verifier_address}{Colors.RESET}")

        return [owner_address, nft_address, token_simulation_address, verifier_address]

    def validate_dependencies(self, nft_address: str = None, token_simulation_address: str = None, **kwargs) -> bool:
        """Registry requires NFT address and TokenSimulation address."""
        if not nft_address:
            print(f"{Colors.ERROR}✗ NFT address is required for Registry deployment{Colors.RESET}")
            return False
        if not token_simulation_address:
            print(f"{Colors.ERROR}✗ TokenSimulation address is required for Registry deployment{Colors.RESET}")
            return False
        return True

    def get_dependency_info(self, nft_address: str = None, token_simulation_address: str = None, verifier_address: str = None, **kwargs) -> List[str]:
        """Get dependency information."""
        deps = []
        if nft_address:
            deps.append(f"NFT Contract: {nft_address}")
        if token_simulation_address:
            deps.append(f"TokenSimulation Contract: {token_simulation_address}")
        if verifier_address and verifier_address != "0x0":
            deps.append(f"Verifier Contract: {verifier_address}")
        return deps


class KliverTokensCore(BaseContract):
    """Kliver Tokens Core (ERC1155) contract."""
    
    def __init__(self):
        super().__init__("KliverTokensCore", "KliverTokensCore")
    
    def get_constructor_calldata(self, owner_address: str, base_uri: str = "", **kwargs) -> List[str]:
        """Kliver1155 requires: owner + base_uri (ByteArray)"""
        if not base_uri:
            base_uri = "https://api.kliver.io/metadata/"
            print(f"{Colors.WARNING}⚠️  No base_uri provided, using default: {base_uri}{Colors.RESET}")
        else:
            print(f"{Colors.INFO}📋 Using base URI: {base_uri}{Colors.RESET}")
        
        base_uri_calldata = StarknetUtils.string_to_bytearray_calldata(base_uri)
        return [owner_address] + base_uri_calldata
    
    def validate_dependencies(self, **kwargs) -> bool:
        """Token1155 has no dependencies."""
        return True


# Contract factory
CONTRACTS = {
    "nft": KliverNFT,
    "registry": KliverRegistry,
    "kliver_tokens_core": KliverTokensCore,
}


def get_contract(contract_type: str) -> BaseContract:
    """Get a contract instance by type."""
    if contract_type not in CONTRACTS:
        available = list(CONTRACTS.keys())
        raise ValueError(f"Unknown contract type '{contract_type}'. Available: {available}")
    
    return CONTRACTS[contract_type]()


# Additional marketplace contracts
class SessionMarketplace(BaseContract):
    def __init__(self):
        super().__init__("SessionMarketplace", "SessionMarketplace")

    def get_constructor_calldata(self, owner_address: str = "0x0", registry_address: str = None, **kwargs) -> List[str]:
        if not registry_address:
            raise ValueError("registry_address is required for SessionMarketplace")
        print(f"{Colors.INFO}📋 Using Registry address: {registry_address}{Colors.RESET}")
        return [registry_address]

    def validate_dependencies(self, registry_address: str = None, **kwargs) -> bool:
        if not registry_address:
            print(f"{Colors.ERROR}✗ Registry address is required for SessionMarketplace deployment{Colors.RESET}")
            return False
        return True


class SessionsMarketplace(BaseContract):
    def __init__(self):
        super().__init__("SessionsMarketplace", "SessionsMarketplace")

    def get_constructor_calldata(
        self,
        owner_address: str = "0x0",
        pox_address: str = None,
        verifier_address: str = None,
        payment_token_address: str = None,
        purchase_timeout_seconds: int = 0,
        **kwargs,
    ) -> List[str]:
        if not pox_address or not verifier_address or not payment_token_address or not purchase_timeout_seconds:
            raise ValueError("pox_address, verifier_address, payment_token_address and purchase_timeout_seconds are required for SessionsMarketplace")
        print(f"{Colors.INFO}📋 Using PoX: {pox_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using Verifier: {verifier_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using Payment Token: {payment_token_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using Timeout (s): {purchase_timeout_seconds}{Colors.RESET}")
        return [pox_address, verifier_address, payment_token_address, str(purchase_timeout_seconds)]

    def validate_dependencies(
        self,
        pox_address: str = None,
        verifier_address: str = None,
        payment_token_address: str = None,
        purchase_timeout_seconds: int = 0,
        **kwargs,
    ) -> bool:
        ok = True
        if not pox_address:
            print(f"{Colors.ERROR}✗ PoX address is required for SessionsMarketplace deployment{Colors.RESET}")
            ok = False
        if not verifier_address:
            print(f"{Colors.ERROR}✗ Verifier address is required for SessionsMarketplace deployment{Colors.RESET}")
            ok = False
        if not payment_token_address:
            print(f"{Colors.ERROR}✗ Payment token address is required for SessionsMarketplace deployment{Colors.RESET}")
            ok = False
        if not purchase_timeout_seconds:
            print(f"{Colors.ERROR}✗ purchase_timeout_seconds is required for SessionsMarketplace deployment{Colors.RESET}")
            ok = False
        return ok


# Register new contracts in factory
CONTRACTS.update({
    "session_marketplace": SessionMarketplace,
    "sessions_marketplace": SessionsMarketplace,
})


class KlivePox(BaseContract):
    """KlivePox contract (mints session NFTs from Registry)."""

    def __init__(self):
        super().__init__("KlivePox", "KlivePox")

    def get_constructor_calldata(self, owner_address: str = "0x0", registry_address: str = None, **kwargs) -> List[str]:
        if not registry_address:
            raise ValueError("registry_address is required for KlivePox")
        print(f"{Colors.INFO}📋 Using Registry address: {registry_address}{Colors.RESET}")
        return [registry_address]

    def validate_dependencies(self, registry_address: str = None, **kwargs) -> bool:
        if not registry_address:
            print(f"{Colors.ERROR}✗ Registry address is required for KlivePox deployment{Colors.RESET}")
            return False
        return True


# Add KlivePox to factory
CONTRACTS.update({
    "klive_pox": KlivePox,
})


class SimpleERC20(BaseContract):
    """Simple ERC20 token contract for demo purposes."""

    def __init__(self):
        super().__init__("SimpleERC20", "SimpleERC20")

    def get_constructor_calldata(self, owner_address: str = "0x0", **kwargs) -> List[str]:
        """SimpleERC20 requires no parameters - mints to contract itself"""
        print(f"{Colors.INFO}📋 SimpleERC20 mints total supply to contract itself{Colors.RESET}")
        return []

    def validate_dependencies(self, **kwargs) -> bool:
        """SimpleERC20 has no dependencies."""
        return True


# Add SimpleERC20 to factory
CONTRACTS.update({
    "simple_erc20": SimpleERC20,
})
