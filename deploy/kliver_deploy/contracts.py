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
                               verifier_address: str = "0x0", **kwargs) -> List[str]:
        """Registry requires: owner + nft_address + verifier_address"""
        print(f"{Colors.INFO}📋 Using NFT address: {nft_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using Verifier address: {verifier_address}{Colors.RESET}")
        
        return [owner_address, nft_address, verifier_address]
    
    def validate_dependencies(self, nft_address: str = None, **kwargs) -> bool:
        """Registry requires NFT address."""
        if not nft_address:
            print(f"{Colors.ERROR}✗ NFT address is required for Registry deployment{Colors.RESET}")
            return False
        return True
    
    def get_dependency_info(self, nft_address: str = None, verifier_address: str = None, **kwargs) -> List[str]:
        """Get dependency information."""
        deps = []
        if nft_address:
            deps.append(f"NFT Contract: {nft_address}")
        if verifier_address and verifier_address != "0x0":
            deps.append(f"Verifier Contract: {verifier_address}")
        return deps


class KliverNFT1155(BaseContract):
    """Kliver NFT 1155 (ERC1155) contract."""
    
    def __init__(self):
        super().__init__("KliverNFT1155", "KliverNFT1155")
    
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


class SimulationCore(BaseContract):
    """Simulation Core contract."""
    
    def __init__(self):
        super().__init__("SimulationCore", "SimulationCore")
    
    def get_constructor_calldata(self, owner_address: str, registry_address: str, 
                               token_address: str, **kwargs) -> List[str]:
        """SimulationCore requires: registry_address + token_address + owner"""
        print(f"{Colors.INFO}📋 Using Registry address: {registry_address}{Colors.RESET}")
        print(f"{Colors.INFO}📋 Using Token address: {token_address}{Colors.RESET}")
        
        return [registry_address, token_address, owner_address]
    
    def validate_dependencies(self, registry_address: str = None, token_address: str = None, **kwargs) -> bool:
        """SimulationCore requires both Registry and Token addresses."""
        if not registry_address:
            print(f"{Colors.ERROR}✗ Registry address is required for SimulationCore deployment{Colors.RESET}")
            return False
        if not token_address:
            print(f"{Colors.ERROR}✗ Token address is required for SimulationCore deployment{Colors.RESET}")
            return False
        return True
    
    def get_dependency_info(self, registry_address: str = None, token_address: str = None, **kwargs) -> List[str]:
        """Get dependency information."""
        deps = []
        if registry_address:
            deps.append(f"Registry Contract: {registry_address}")
        if token_address:
            deps.append(f"Token Contract: {token_address}")
        return deps


# Contract factory
CONTRACTS = {
    "nft": KliverNFT,
    "registry": KliverRegistry,
    "kliver_1155": KliverNFT1155,
    "simulation_core": SimulationCore
}


def get_contract(contract_type: str) -> BaseContract:
    """Get a contract instance by type."""
    if contract_type not in CONTRACTS:
        available = list(CONTRACTS.keys())
        raise ValueError(f"Unknown contract type '{contract_type}'. Available: {available}")
    
    return CONTRACTS[contract_type]()