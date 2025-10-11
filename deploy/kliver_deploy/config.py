"""
Configuration management for Kliver contract deployments.
"""

import yaml
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass


@dataclass
class NetworkConfig:
    """Configuration for a specific network environment."""
    name: str
    network: str
    rpc_url: str
    explorer: str
    chain_id: str
    description: str
    account: str
    build_target: str
    

@dataclass
class ContractConfig:
    """Configuration for a specific contract."""
    name: str
    sierra_file: str
    base_uri: Optional[str] = None
    verifier_address: Optional[str] = None
    payment_token_address: Optional[str] = None
    purchase_timeout_seconds: Optional[int] = None


@dataclass 
class DeploymentSettings:
    """Deployment-specific settings."""
    wait_timeout: int = 120
    retry_interval: int = 2
    max_retries: int = 20


class ConfigManager:
    """Manages deployment configuration for different environments."""
    
    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize ConfigManager.
        
        Args:
            config_path: Path to the configuration file. If None, looks for
                        deployment_config.yml in the current directory.
        """
        if config_path is None:
            config_path = Path.cwd() / "deployment_config.yml"
        
        self.config_path = config_path
        self._config_data: Optional[Dict[str, Any]] = None
        
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        if self._config_data is None:
            if not self.config_path.exists():
                raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
            
            with open(self.config_path, 'r') as f:
                self._config_data = yaml.safe_load(f)
                
        return self._config_data
    
    def get_environment_config(self, environment: str) -> NetworkConfig:
        """Get configuration for a specific environment."""
        config = self.load_config()
        
        if environment not in config.get("environments", {}):
            available = list(config.get("environments", {}).keys())
            raise ValueError(f"Environment '{environment}' not found. Available: {available}")
        
        env_data = config["environments"][environment]
        
        # Validate required fields
        required_fields = ['name', 'network', 'rpc_url', 'account']
        for field in required_fields:
            if field not in env_data:
                raise ValueError(f"Missing required field '{field}' in environment '{environment}'")
        
        return NetworkConfig(
            name=env_data['name'],
            network=env_data['network'],
            rpc_url=env_data['rpc_url'],
            explorer=env_data.get('explorer', ''),
            chain_id=env_data.get('chain_id', ''),
            description=env_data.get('description', ''),
            account=env_data['account'],
            build_target=env_data.get('build_target', 'dev')
        )
    
    def get_contract_config(self, environment: str, contract_name: str) -> ContractConfig:
        """Get configuration for a specific contract in an environment."""
        config = self.load_config()
        
        env_config = config["environments"][environment]
        contracts = env_config.get("contracts", {})
        
        if contract_name not in contracts:
            available = list(contracts.keys())
            raise ValueError(f"Contract '{contract_name}' not found in environment '{environment}'. Available: {available}")
        
        contract_data = contracts[contract_name]
        
        return ContractConfig(
            name=contract_data['name'],
            sierra_file=contract_data['sierra_file'],
            base_uri=contract_data.get('base_uri'),
            verifier_address=contract_data.get('verifier_address'),
            payment_token_address=contract_data.get('payment_token_address'),
            purchase_timeout_seconds=contract_data.get('purchase_timeout_seconds'),
        )
    
    def get_deployment_settings(self, environment: str) -> DeploymentSettings:
        """Get deployment settings for an environment."""
        config = self.load_config()
        
        env_config = config["environments"][environment]
        settings_data = env_config.get("deployment_settings", {})
        
        return DeploymentSettings(
            wait_timeout=settings_data.get('wait_timeout', 120),
            retry_interval=settings_data.get('retry_interval', 2),
            max_retries=settings_data.get('max_retries', 20)
        )
    
    def get_available_environments(self) -> list[str]:
        """Get list of available environments."""
        config = self.load_config()
        return list(config.get("environments", {}).keys())
    
    def get_available_contracts(self, environment: str) -> list[str]:
        """Get list of available contracts for an environment."""
        config = self.load_config()
        env_config = config["environments"][environment]
        return list(env_config.get("contracts", {}).keys())
