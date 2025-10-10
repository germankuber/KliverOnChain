"""
Utility functions for Kliver contract deployment.
"""

import subprocess
import time
import re
import json
from pathlib import Path
from typing import Dict, Any, List
from colorama import Fore, Style, init

# Initialize colorama for cross-platform colored output
init()


class Colors:
    """Color constants for terminal output"""
    SUCCESS = Fore.GREEN
    ERROR = Fore.RED
    WARNING = Fore.YELLOW
    INFO = Fore.BLUE
    CYAN = Fore.CYAN
    BOLD = Style.BRIGHT
    RESET = Style.RESET_ALL


class CommandRunner:
    """Handles running shell commands with proper error handling."""
    
    @staticmethod
    def run_command(command: List[str], description: str, show_output: bool = False) -> Dict[str, Any]:
        """Execute a shell command and return the result."""
        try:
            # Find project root by looking for Scarb.toml
            project_root = Path.cwd()
            while project_root != project_root.parent:
                if (project_root / "Scarb.toml").exists():
                    break
                project_root = project_root.parent
            
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True,
                cwd=project_root  # Run from project root
            )
            
            if show_output and result.stdout.strip():
                print(f"{Colors.INFO}➤ {description}...{Colors.RESET}")
                print(f"{result.stdout.strip()}")
                
            return {
                "success": True,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
            
        except subprocess.CalledProcessError as e:
            print(f"{Colors.ERROR}✗ {description} failed{Colors.RESET}")
            if e.stderr:
                print(f"{Colors.ERROR}Error: {e.stderr.strip()}{Colors.RESET}")
            return {
                "success": False,
                "stdout": e.stdout or "",
                "stderr": e.stderr or "",
                "returncode": e.returncode
            }


class StarknetUtils:
    """Utilities for StarkNet operations."""
    
    @staticmethod
    def string_to_bytearray_calldata(text: str) -> List[str]:
        """Convert a string to Cairo ByteArray calldata format."""
        if not text:
            return ["0", "0", "0"]

        # Encode string to bytes
        text_bytes = text.encode('utf-8')

        # Split into 31-byte chunks (Cairo felts can hold 31 bytes max)
        chunk_size = 31
        chunks = []

        for i in range(0, len(text_bytes), chunk_size):
            chunk = text_bytes[i:i + chunk_size]
            # Convert chunk to integer (big-endian)
            chunk_int = int.from_bytes(chunk, byteorder='big')
            chunks.append(str(chunk_int))

        # Last chunk becomes pending_word
        if chunks:
            pending_word = chunks[-1]
            full_words = chunks[:-1] if len(chunks) > 1 else []
            last_chunk_len = len(text_bytes) % chunk_size
            if last_chunk_len == 0 and len(text_bytes) > 0:
                last_chunk_len = chunk_size
        else:
            pending_word = "0"
            full_words = []
            last_chunk_len = 0

        # Format: [data_len, word1, word2, ..., pending_word, pending_word_len]
        result = [str(len(full_words))] + full_words + [pending_word, str(last_chunk_len)]
        return result
    
    @staticmethod
    def parse_contract_address(output: str) -> str:
        """Parse contract address from sncast deploy output."""
        patterns = [
            r"(?:contract_address:|Contract Address:)\s*(0x[a-fA-F0-9]+)",
            r"Contract deployed at:\s*(0x[a-fA-F0-9]+)",
            r"Deployed contract address:\s*(0x[a-fA-F0-9]+)"
        ]
        
        for pattern in patterns:
            match = re.search(pattern, output)
            if match:
                return match.group(1)
        
        raise ValueError("Could not parse contract address from output")
    
    @staticmethod
    def parse_class_hash(output: str) -> str:
        """Parse class hash from sncast declare output."""
        patterns = [
            r"(?:class_hash:|Class Hash:)\s*(0x[a-fA-F0-9]+)",
            r"Contract class hash:\s*(0x[a-fA-F0-9]+)",
            r"Declared class hash:\s*(0x[a-fA-F0-9]+)"
        ]
        
        for pattern in patterns:
            match = re.search(pattern, output)
            if match:
                return match.group(1)
        
        raise ValueError("Could not parse class hash from output")
    
    @staticmethod
    def parse_transaction_hash(output: str) -> str:
        """Parse transaction hash from sncast output."""
        patterns = [
            r"(?:transaction_hash:|Transaction Hash:)\s*(0x[a-fA-F0-9]+)",
            r"Transaction hash:\s*(0x[a-fA-F0-9]+)",
            r"Tx hash:\s*(0x[a-fA-F0-9]+)"
        ]
        
        for pattern in patterns:
            match = re.search(pattern, output)
            if match:
                return match.group(1)
        
        raise ValueError("Could not parse transaction hash from output")


class TransactionWaiter:
    """Handles waiting for transaction confirmation."""
    
    def __init__(self, account: str, rpc_url: str):
        self.account = account
        self.rpc_url = rpc_url
    
    def wait_for_confirmation(self, tx_hash: str, max_attempts: int = 60) -> bool:
        """Wait for transaction confirmation."""
        print(f"{Colors.INFO}⏳ Waiting for transaction confirmation: {tx_hash}{Colors.RESET}")
        
        for attempt in range(max_attempts):
            command = [
                "sncast", "--account", self.account, "tx-status",
                tx_hash, "--url", self.rpc_url
            ]
            
            result = CommandRunner.run_command(command, f"Checking transaction status (attempt {attempt + 1})")
            
            if result["success"] and ("AcceptedOnL2" in result["stdout"] or "Succeeded" in result["stdout"]):
                print(f"{Colors.SUCCESS}✓ Transaction confirmed{Colors.RESET}")
                return True
                
            if attempt < max_attempts - 1:  # Don't sleep on the last attempt
                print(f"{Colors.WARNING}⏳ Transaction still pending... waiting 5 seconds (attempt {attempt + 1}/{max_attempts}){Colors.RESET}")
                time.sleep(5)
            
        print(f"{Colors.ERROR}✗ Transaction confirmation timeout after {max_attempts * 5} seconds{Colors.RESET}")
        return False


def format_address(address: str, start_chars: int = 10, end_chars: int = 4) -> str:
    """Format a long address for display."""
    if len(address) <= start_chars + end_chars:
        return address
    return f"{address[:start_chars]}...{address[-end_chars:]}"


def print_deployment_summary(deployments: List[Dict[str, Any]], network: str):
    """Print a clean summary of all deployments."""
    if not deployments:
        return
        
    print(f"\n{Colors.BOLD}{'='*70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.SUCCESS}🎉 DEPLOYMENT SUMMARY{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*70}{Colors.RESET}")
    
    for i, deployment in enumerate(deployments, 1):
        contract_name = deployment['contract_name']
        contract_address = deployment['contract_address']
        
        print(f"\n{Colors.BOLD}{i}. {contract_name.upper()}{Colors.RESET}")
        print(f"   Address:    {Colors.SUCCESS}{Colors.BOLD}{contract_address}{Colors.RESET}")
        print(f"   Explorer:   {Colors.INFO}https://sepolia.starkscan.co/contract/{contract_address}{Colors.RESET}")
        print(f"   Class Hash: {format_address(deployment['class_hash'])}")
        
        # Show dependencies if present
        dependencies = []
        if deployment.get('nft_address'):
            dependencies.append(f"NFT: {format_address(deployment['nft_address'])}")
        if deployment.get('registry_address'):
            dependencies.append(f"Registry: {format_address(deployment['registry_address'])}")
        if deployment.get('token_address'):
            dependencies.append(f"Token: {format_address(deployment['token_address'])}")
        
        if dependencies:
            print(f"   Dependencies: {', '.join(dependencies)}")
    
    print(f"\n{Colors.BOLD}Network: {network.upper()} | Owner: {format_address(deployments[0]['owner'])}{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*70}{Colors.RESET}")


def print_deployment_json(deployments: List[Dict[str, Any]]):
    """Print deployment addresses in JSON format."""
    if not deployments:
        return
    
    # Create a mapping of contract types to addresses with the specified keys
    json_output = {
        "Nft": "",
        "Registry": "",
        "TokensCore": ""
    }
    
    for deployment in deployments:
        contract_name = deployment['contract_name'].lower()
        contract_address = deployment['contract_address']
        
        if contract_name == 'klivernft':
            json_output['Nft'] = contract_address
        elif contract_name == 'kliver_registry':
            json_output['Registry'] = contract_address
        elif contract_name == 'kliverrc1155':
            json_output['TokensCore'] = contract_address

    
    # Print the JSON output
    print(json.dumps(json_output, indent=2))