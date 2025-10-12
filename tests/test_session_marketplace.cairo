use kliver_on_chain::session_marketplace::{
    ISessionMarketplaceDispatcher, ISessionMarketplaceDispatcherTrait, ListingStatus,
};
use kliver_on_chain::interfaces::session_registry::{ISessionRegistryDispatcher, ISessionRegistryDispatcherTrait};
use kliver_on_chain::components::session_registry_component::SessionMetadata;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_registry() -> ISessionRegistryDispatcher {
    let contract = declare("MockSessionRegistry").unwrap().contract_class();
    let (addr, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    ISessionRegistryDispatcher { contract_address: addr }
}

fn deploy_session_marketplace(registry: ContractAddress) -> ISessionMarketplaceDispatcher {
    let contract = declare("SessionMarketplace").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    calldata.append(registry.into());
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    ISessionMarketplaceDispatcher { contract_address }
}

fn SELLER() -> ContractAddress {
    'seller'.try_into().unwrap()
}

fn BUYER() -> ContractAddress {
    'buyer'.try_into().unwrap()
}

fn OTHER_USER() -> ContractAddress {
    'other_user'.try_into().unwrap()
}

#[test]
fn test_publish_session() {
    let registry = deploy_registry();
    // Register a session (owner SELLER)
    let meta = SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 };
    registry.register_session(meta);
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    marketplace.publish_session(simulation_id, session_id, price);

    stop_cheat_caller_address(marketplace.contract_address);

    // Verificar que la sesión existe
    assert!(marketplace.session_exists(session_id), "Session should exist");
    assert!(marketplace.is_available(session_id), "Session should be available");

    // Obtener la sesión y verificar los datos
    let listing = marketplace.get_session(session_id);
    assert!(listing.session_id == session_id, "Session ID mismatch");
    assert!(listing.simulation_id == simulation_id, "Simulation ID mismatch");
    assert!(listing.root_hash == 'root_hash_1', "Root hash mismatch");
    assert!(listing.price == price, "Price mismatch");
    assert!(listing.seller == SELLER(), "Seller mismatch");
    assert!(listing.status == ListingStatus::Available, "Status should be Available");
}

#[test]
#[should_panic(expected: ('Session already exists',))]
fn test_publish_duplicate_session() {
    let registry = deploy_registry();
    let meta = SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 };
    registry.register_session(meta);
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    // Publicar la primera vez
    marketplace.publish_session(simulation_id, session_id, price);

    // Intentar publicar de nuevo (debería fallar)
    marketplace.publish_session(simulation_id, session_id, price);
}

#[test]
#[should_panic(expected: ('Price must be greater than 0',))]
fn test_publish_session_zero_price() {
    let registry = deploy_registry();
    let meta = SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 };
    registry.register_session(meta);
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 0;

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    marketplace.publish_session(simulation_id, session_id, price);
}

#[test]
fn test_purchase_session() {
    let registry = deploy_registry();
    let meta = SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 };
    registry.register_session(meta);
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    // Publicar sesión como SELLER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.publish_session(simulation_id, session_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Comprar sesión como BUYER
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.purchase_session(session_id);
    stop_cheat_caller_address(marketplace.contract_address);

    // Verificar que la sesión fue vendida
    let listing = marketplace.get_session(session_id);
    assert!(listing.buyer == BUYER(), "Buyer should be set");
    assert!(listing.status == ListingStatus::Sold, "Status should be Sold");
    assert!(!marketplace.is_available(session_id), "Session should not be available");
}

#[test]
#[should_panic(expected: ('Cannot buy your own session',))]
fn test_purchase_own_session() {
    let registry = deploy_registry();
    let meta = SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 };
    registry.register_session(meta);
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    // Publicar sesión
    marketplace.publish_session(simulation_id, session_id, price);

    // Intentar comprar propia sesión (debería fallar)
    marketplace.purchase_session(session_id);
}

#[test]
#[should_panic(expected: ('Session not available',))]
fn test_purchase_sold_session() {
    let registry = deploy_registry();
    let meta = SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 };
    registry.register_session(meta);
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    // Publicar sesión como SELLER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.publish_session(simulation_id, session_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Comprar sesión como BUYER
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.purchase_session(session_id);
    stop_cheat_caller_address(marketplace.contract_address);

    // Intentar comprar de nuevo como OTHER_USER (debería fallar)
    start_cheat_caller_address(marketplace.contract_address, OTHER_USER());
    marketplace.purchase_session(session_id);
}

#[test]
fn test_get_sessions_by_simulation() {
    let registry = deploy_registry();
    // Register three sessions for SELLER
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_2', root_hash: 'root_2', simulation_id: 'sim_1', author: SELLER(), score: 200_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_3', root_hash: 'root_3', simulation_id: 'sim_1', author: SELLER(), score: 150_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    // Publicar múltiples sesiones para la misma simulación
    marketplace.publish_session(simulation_id, 'session_1', 50);
    marketplace.publish_session(simulation_id, 'session_2', 75);
    marketplace.publish_session(simulation_id, 'session_3', 60);

    stop_cheat_caller_address(marketplace.contract_address);

    // Obtener todas las sesiones de la simulación
    let sessions = marketplace.get_sessions_by_simulation(simulation_id);

    assert!(sessions.len() == 3, "Should have 3 sessions");

    // Verificar los IDs de las sesiones
    assert!(*sessions.at(0).session_id == 'session_1', "First session ID mismatch");
    assert!(*sessions.at(1).session_id == 'session_2', "Second session ID mismatch");
    assert!(*sessions.at(2).session_id == 'session_3', "Third session ID mismatch");
}

#[test]
fn test_remove_session() {
    let registry = deploy_registry();
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    // Publicar sesión
    marketplace.publish_session(simulation_id, session_id, price);

    // Verificar que existe
    assert!(marketplace.session_exists(session_id), "Session should exist");

    // Cancelar sesión
    marketplace.remove_session(session_id);

    stop_cheat_caller_address(marketplace.contract_address);

    // Verificar que ya no existe (fue cancelada)
    assert!(!marketplace.session_exists(session_id), "Session should not exist");
    assert!(!marketplace.is_available(session_id), "Session should not be available");
}

#[test]
#[should_panic(expected: ('Not the seller',))]
fn test_remove_session_wrong_seller() {
    let registry = deploy_registry();
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    // Publicar como SELLER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.publish_session(simulation_id, session_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Intentar cancelar como OTHER_USER (debería fallar)
    start_cheat_caller_address(marketplace.contract_address, OTHER_USER());
    marketplace.remove_session(session_id);
}

#[test]
#[should_panic(expected: ('Cannot cancel sold session',))]
fn test_remove_sold_session() {
    let registry = deploy_registry();
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_hash_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';
    let price = 50;

    // Publicar sesión como SELLER
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.publish_session(simulation_id, session_id, price);
    stop_cheat_caller_address(marketplace.contract_address);

    // Comprar sesión como BUYER
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.purchase_session(session_id);
    stop_cheat_caller_address(marketplace.contract_address);

    // Intentar cancelar como SELLER (debería fallar porque ya fue vendida)
    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.remove_session(session_id);
}

#[test]
fn test_cancelled_session_not_in_list() {
    let registry = deploy_registry();
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_2', root_hash: 'root_2', simulation_id: 'sim_1', author: SELLER(), score: 200_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_3', root_hash: 'root_3', simulation_id: 'sim_1', author: SELLER(), score: 150_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    // Publicar tres sesiones
    marketplace.publish_session(simulation_id, 'session_1', 50);
    marketplace.publish_session(simulation_id, 'session_2', 75);
    marketplace.publish_session(simulation_id, 'session_3', 60);

    // Cancelar la segunda sesión
    marketplace.remove_session('session_2');

    stop_cheat_caller_address(marketplace.contract_address);

    // Obtener las sesiones de la simulación
    let sessions = marketplace.get_sessions_by_simulation(simulation_id);

    // Debería haber solo 2 sesiones (la cancelada no debería aparecer)
    assert!(sessions.len() == 2, "Should have 2 sessions after cancellation");

    // Verificar que session_2 no está en la lista
    assert!(*sessions.at(0).session_id == 'session_1', "First session should be session_1");
    assert!(*sessions.at(1).session_id == 'session_3', "Second session should be session_3");
}

#[test]
fn test_multiple_simulations() {
    let registry = deploy_registry();
    // Sessions for two simulations
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_2', root_hash: 'root_2', simulation_id: 'sim_1', author: SELLER(), score: 200_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_3', root_hash: 'root_3', simulation_id: 'sim_2', author: SELLER(), score: 150_u32 });
    registry.register_session(SessionMetadata { session_id: 'session_4', root_hash: 'root_4', simulation_id: 'sim_2', author: SELLER(), score: 180_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    start_cheat_caller_address(marketplace.contract_address, SELLER());

    // Publicar sesiones para diferentes simulaciones
    marketplace.publish_session('sim_1', 'session_1', 50);
    marketplace.publish_session('sim_1', 'session_2', 75);
    marketplace.publish_session('sim_2', 'session_3', 60);
    marketplace.publish_session('sim_2', 'session_4', 65);

    stop_cheat_caller_address(marketplace.contract_address);

    // Verificar sesiones de sim_1
    let sessions_sim1 = marketplace.get_sessions_by_simulation('sim_1');
    assert!(sessions_sim1.len() == 2, "Sim 1 should have 2 sessions");

    // Verificar sesiones de sim_2
    let sessions_sim2 = marketplace.get_sessions_by_simulation('sim_2');
    assert!(sessions_sim2.len() == 2, "Sim 2 should have 2 sessions");
}

#[test]
#[should_panic(expected: ('Session does not exist',))]
fn test_get_nonexistent_session() {
    let registry = deploy_registry();
    let marketplace = deploy_session_marketplace(registry.contract_address);

    // Intentar obtener una sesión que no existe
    marketplace.get_session('nonexistent');
}

#[test]
fn test_is_available() {
    let registry = deploy_registry();
    registry.register_session(SessionMetadata { session_id: 'session_1', root_hash: 'root_1', simulation_id: 'sim_1', author: SELLER(), score: 100_u32 });
    let marketplace = deploy_session_marketplace(registry.contract_address);

    let simulation_id = 'sim_1';
    let session_id = 'session_1';

    // Verificar que una sesión inexistente no está disponible
    assert!(!marketplace.is_available(session_id), "Nonexistent session should not be available");

    start_cheat_caller_address(marketplace.contract_address, SELLER());
    marketplace.publish_session(simulation_id, session_id, 50);
    stop_cheat_caller_address(marketplace.contract_address);

    // Verificar que está disponible después de publicarla
    assert!(marketplace.is_available(session_id), "Published session should be available");

    // Comprarla
    start_cheat_caller_address(marketplace.contract_address, BUYER());
    marketplace.purchase_session(session_id);
    stop_cheat_caller_address(marketplace.contract_address);

    // Verificar que ya no está disponible
    assert!(!marketplace.is_available(session_id), "Sold session should not be available");
}
