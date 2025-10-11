#!/usr/bin/env python3
"""
Script to fix test cases that call register_simulation without setting up registry first.
"""

import re

def fix_test_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Pattern 1: register_simulation called while owner is the caller
    # We need to stop the owner context, setup registry, call as registry, then resume owner context
    pattern1 = re.compile(
        r'(    // Register(?:.*?)simulation[^\n]*\n'
        r'    )(dispatcher\.register_simulation\([^)]+\);)',
        re.MULTILINE
    )

    def replacement1(match):
        comment = match.group(1)
        call = match.group(2)
        return (
            f"{comment}stop_cheat_caller_address(dispatcher.contract_address);\n"
            f"    let registry = setup_registry(dispatcher, owner);\n"
            f"    start_cheat_caller_address(dispatcher.contract_address, registry);\n"
            f"    {call}\n"
            f"    stop_cheat_caller_address(dispatcher.contract_address);\n"
            f"    start_cheat_caller_address(dispatcher.contract_address, owner);\n"
        )

    # First pass - fix cases where we're in owner context
    lines = content.split('\n')
    fixed_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if this is a register_simulation call
        if 'dispatcher.register_simulation(' in line and 'setup_simulation_with_registry' not in line:
            # Check if we have setup_registry in the lines above this test function
            # Look backward to find the start of the test function
            test_start = i
            for j in range(i-1, max(0, i-50), -1):
                if 'fn test_' in lines[j]:
                    test_start = j
                    break

            # Check if setup_registry is already in this test
            has_setup = False
            for j in range(test_start, i):
                if 'setup_registry' in lines[j] or 'setup_simulation_with_registry' in lines[j]:
                    has_setup = True
                    break

            if not has_setup:
                # Check if we're in owner context (look for start_cheat_caller_address with owner)
                in_owner_context = False
                for j in range(i-1, max(0, i-20), -1):
                    if 'start_cheat_caller_address(dispatcher.contract_address, owner)' in lines[j]:
                        in_owner_context = True
                        break
                    if 'stop_cheat_caller_address' in lines[j]:
                        break

                if in_owner_context:
                    # Insert the registry setup before the register_simulation call
                    fixed_lines.append("    stop_cheat_caller_address(dispatcher.contract_address);")
                    fixed_lines.append("    let registry = setup_registry(dispatcher, owner);")
                    fixed_lines.append("    start_cheat_caller_address(dispatcher.contract_address, registry);")
                    fixed_lines.append(line)
                    fixed_lines.append("    stop_cheat_caller_address(dispatcher.contract_address);")
                    fixed_lines.append("    start_cheat_caller_address(dispatcher.contract_address, owner);")
                    i += 1
                    continue

        fixed_lines.append(line)
        i += 1

    return '\n'.join(fixed_lines)

if __name__ == '__main__':
    import sys
    file_path = '../tests/test_kliver_nft_1155.cairo'

    print(f"Fixing {file_path}...")
    fixed_content = fix_test_file(file_path)

    # Write to output file for review
    with open(file_path + '.fixed', 'w') as f:
        f.write(fixed_content)

    print(f"Fixed content written to {file_path}.fixed")
    print("Please review the changes before applying them.")
