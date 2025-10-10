#[cfg(test)]
fn test_claim_previous_days_logic() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();

    // Setup simulation with release hour at 8:00 AM (hour 8)
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);

    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100, 8); // Release at 8:00 AM
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);

    // === ESCENARIO 1: Lunes - Claim normal ===
    // Lunes a las 10:00 AM (después de las 8:00 AM)
    let monday_10am = 1000 + 86400 + (10 * 3600); // day 1 at 10:00 AM
    start_cheat_block_timestamp(core_address, monday_10am);
    start_cheat_caller_address(core_address, user);
    core.claim_tokens('sim_1'); // Debe funcionar
    stop_cheat_caller_address(core_address);

    // Verificar que recibió tokens del lunes
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data = core.get_simulation_data('sim_1');
    let balance_monday = token.balance_of(user, sim_data.token_id);
    assert(balance_monday == 100, 'Should have 100 tokens from Monday');

    // === ESCENARIO 2: Martes - NO claimea ===
    // Avanzamos al martes pero no claimeamos

    // === ESCENARIO 3: Miércoles ANTES de las 8:00 AM ===
    // Miércoles a las 6:00 AM (antes de las 8:00 AM)
    let wednesday_6am = 1000 + (3 * 86400) + (6 * 3600); // day 3 at 6:00 AM
    start_cheat_block_timestamp(core_address, wednesday_6am);
    start_cheat_caller_address(core_address, user);

    // Debe poder claimear SOLO lo del martes (día 2)
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);

    // Verificar que recibió 100 tokens adicionales del martes
    let balance_tuesday = token.balance_of(user, sim_data.token_id);
    assert(balance_tuesday == 200, 'Should have 200 tokens (Mon+Tue)');

    // === ESCENARIO 4: Miércoles DESPUÉS de las 8:00 AM ===
    // Reiniciar para probar el otro caso
    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_claim_previous_days_after_release_hour() {
    let (core_address, registry_address, token_address, owner) = setup();
    let core = ISimulationCoreDispatcher { contract_address: core_address };
    let user: ContractAddress = contract_address_const::<0x456>();

    // Setup simulation with release hour at 8:00 AM (hour 8)
    let registry = IMockRegistryHelperDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, owner);
    registry.add_simulation('sim_1');
    stop_cheat_caller_address(registry_address);

    start_cheat_caller_address(core_address, owner);
    core.register_simulation('sim_1', 100, 8); // Release at 8:00 AM
    core.add_to_whitelist('sim_1', user);
    stop_cheat_caller_address(core_address);

    // === ESCENARIO: Usuario NO claimea Lunes ni Martes ===
    // Miércoles a las 10:00 AM (después de las 8:00 AM)
    let wednesday_10am = 1000 + (3 * 86400) + (10 * 3600); // day 3 at 10:00 AM
    start_cheat_block_timestamp(core_address, wednesday_10am);
    start_cheat_caller_address(core_address, user);

    // Debe poder claimear Lunes + Martes + Miércoles = 3 días
    core.claim_tokens('sim_1');
    stop_cheat_caller_address(core_address);

    // Verificar que recibió 300 tokens (3 días)
    let token = IKliver1155Dispatcher { contract_address: token_address };
    let sim_data = core.get_simulation_data('sim_1');
    let balance = token.balance_of(user, sim_data.token_id);
    assert(balance == 300, 'Should have 300 tokens (Mon+Tue+Wed)');

    stop_cheat_block_timestamp(core_address);
}
