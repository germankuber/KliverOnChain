use kliver_on_chain::session_escrow::{ISessionEscrowDispatcher, ISessionEscrowDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_session_escrow() -> ISessionEscrowDispatcher {
    let contract = declare("SessionEscrow").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    ISessionEscrowDispatcher { contract_address }
}

fn PUBLISHER() -> ContractAddress {
    'publisher'.try_into().unwrap()
}

fn OTHER_USER() -> ContractAddress {
    'other_user'.try_into().unwrap()
}

#[test]
fn test_publish_session() {
    let escrow = deploy_session_escrow();

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let root_hash = 'root_hash_1';
    let score = 100;
    let price = 50;

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    escrow.publish_session(simulation_id, session_id, root_hash, score, price);

    stop_cheat_caller_address(escrow.contract_address);

    // Verificar que la sesión existe
    assert!(escrow.session_exists(session_id), "Session should exist");

    // Obtener la sesión y verificar los datos
    let session = escrow.get_session(session_id);
    assert!(session.session_id == session_id, "Session ID mismatch");
    assert!(session.simulation_id == simulation_id, "Simulation ID mismatch");
    assert!(session.root_hash == root_hash, "Root hash mismatch");
    assert!(session.score == score, "Score mismatch");
    assert!(session.price == price, "Price mismatch");
    assert!(session.publisher == PUBLISHER(), "Publisher mismatch");
}

#[test]
#[should_panic(expected: ('Session already exists',))]
fn test_publish_duplicate_session() {
    let escrow = deploy_session_escrow();

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let root_hash = 'root_hash_1';
    let score = 100;
    let price = 50;

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    // Publicar la primera vez
    escrow.publish_session(simulation_id, session_id, root_hash, score, price);

    // Intentar publicar de nuevo (debería fallar)
    escrow.publish_session(simulation_id, session_id, root_hash, score, price);
}

#[test]
fn test_get_sessions_by_simulation() {
    let escrow = deploy_session_escrow();

    let simulation_id = 'sim_1';

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    // Publicar múltiples sesiones para la misma simulación
    escrow.publish_session(simulation_id, 'session_1', 'root_1', 100, 50);
    escrow.publish_session(simulation_id, 'session_2', 'root_2', 200, 75);
    escrow.publish_session(simulation_id, 'session_3', 'root_3', 150, 60);

    stop_cheat_caller_address(escrow.contract_address);

    // Obtener todas las sesiones de la simulación
    let sessions = escrow.get_sessions_by_simulation(simulation_id);

    assert!(sessions.len() == 3, "Should have 3 sessions");

    // Verificar los IDs de las sesiones
    assert!(*sessions.at(0).session_id == 'session_1', "First session ID mismatch");
    assert!(*sessions.at(1).session_id == 'session_2', "Second session ID mismatch");
    assert!(*sessions.at(2).session_id == 'session_3', "Third session ID mismatch");
}

#[test]
fn test_remove_session() {
    let escrow = deploy_session_escrow();

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let root_hash = 'root_hash_1';
    let score = 100;
    let price = 50;

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    // Publicar sesión
    escrow.publish_session(simulation_id, session_id, root_hash, score, price);

    // Verificar que existe
    assert!(escrow.session_exists(session_id), "Session should exist");

    // Remover sesión
    escrow.remove_session(session_id);

    stop_cheat_caller_address(escrow.contract_address);

    // Verificar que ya no existe
    assert!(!escrow.session_exists(session_id), "Session should not exist");
}

#[test]
#[should_panic(expected: ('Not the publisher',))]
fn test_remove_session_wrong_publisher() {
    let escrow = deploy_session_escrow();

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let root_hash = 'root_hash_1';
    let score = 100;
    let price = 50;

    // Publicar como PUBLISHER
    start_cheat_caller_address(escrow.contract_address, PUBLISHER());
    escrow.publish_session(simulation_id, session_id, root_hash, score, price);
    stop_cheat_caller_address(escrow.contract_address);

    // Intentar remover como OTHER_USER (debería fallar)
    start_cheat_caller_address(escrow.contract_address, OTHER_USER());
    escrow.remove_session(session_id);
}

#[test]
#[should_panic(expected: ('Session does not exist',))]
fn test_remove_nonexistent_session() {
    let escrow = deploy_session_escrow();

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    // Intentar remover una sesión que no existe
    escrow.remove_session('nonexistent');
}

#[test]
fn test_removed_session_not_in_list() {
    let escrow = deploy_session_escrow();

    let simulation_id = 'sim_1';

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    // Publicar tres sesiones
    escrow.publish_session(simulation_id, 'session_1', 'root_1', 100, 50);
    escrow.publish_session(simulation_id, 'session_2', 'root_2', 200, 75);
    escrow.publish_session(simulation_id, 'session_3', 'root_3', 150, 60);

    // Remover la segunda sesión
    escrow.remove_session('session_2');

    stop_cheat_caller_address(escrow.contract_address);

    // Obtener las sesiones de la simulación
    let sessions = escrow.get_sessions_by_simulation(simulation_id);

    // Debería haber solo 2 sesiones (la removida no debería aparecer)
    assert!(sessions.len() == 2, "Should have 2 sessions after removal");

    // Verificar que session_2 no está en la lista
    assert!(*sessions.at(0).session_id == 'session_1', "First session should be session_1");
    assert!(*sessions.at(1).session_id == 'session_3', "Second session should be session_3");
}

#[test]
fn test_multiple_simulations() {
    let escrow = deploy_session_escrow();

    start_cheat_caller_address(escrow.contract_address, PUBLISHER());

    // Publicar sesiones para diferentes simulaciones
    escrow.publish_session('sim_1', 'session_1', 'root_1', 100, 50);
    escrow.publish_session('sim_1', 'session_2', 'root_2', 200, 75);
    escrow.publish_session('sim_2', 'session_3', 'root_3', 150, 60);
    escrow.publish_session('sim_2', 'session_4', 'root_4', 180, 65);

    stop_cheat_caller_address(escrow.contract_address);

    // Verificar sesiones de sim_1
    let sessions_sim1 = escrow.get_sessions_by_simulation('sim_1');
    assert!(sessions_sim1.len() == 2, "Sim 1 should have 2 sessions");

    // Verificar sesiones de sim_2
    let sessions_sim2 = escrow.get_sessions_by_simulation('sim_2');
    assert!(sessions_sim2.len() == 2, "Sim 2 should have 2 sessions");
}

#[test]
#[should_panic(expected: ('Session does not exist',))]
fn test_get_nonexistent_session() {
    let escrow = deploy_session_escrow();

    // Intentar obtener una sesión que no existe
    escrow.get_session('nonexistent');
}
