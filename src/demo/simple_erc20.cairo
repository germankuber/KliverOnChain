#[starknet::contract]
mod SimpleERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Constantes
    const TOTAL_SUPPLY: u256 = 1000000000000000000000000000_u256; // 1 mil millones de tokens (con 18 decimales)
    const CLAIM_AMOUNT: u256 = 100000000000000000000_u256; // 100 tokens por claim

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        // Tracking de claims por usuario
        claimed: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        TokensClaimed: TokensClaimed,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensClaimed {
        #[key]
        claimer: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        recipient: ContractAddress,
    ) {
        // Inicializar con valores fijos
        self.erc20.initializer("Kliver Demo", "KDemo");
        // Mintear todo el supply al recipient (contrato o tesorera)
        self.erc20.mint(recipient, TOTAL_SUPPLY);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Función pública para que cualquiera pueda reclamar tokens
        /// Solo se puede reclamar una vez por dirección
        #[external(v0)]
        fn claim(ref self: ContractState) {
            let caller = starknet::get_caller_address();
            
            // Verificar que no haya reclamado antes
            assert(!self.claimed.read(caller), 'Already claimed');
            
            // Marcar como reclamado
            self.claimed.write(caller, true);
            
            // Transferir tokens desde el contrato al caller
            self.erc20.transfer(caller, CLAIM_AMOUNT);
            
            // Emitir evento
            self.emit(TokensClaimed { claimer: caller, amount: CLAIM_AMOUNT });
        }

        /// Verificar si una dirección ya reclamó tokens
        #[external(v0)]
        fn has_claimed(self: @ContractState, account: ContractAddress) -> bool {
            self.claimed.read(account)
        }

        /// Obtener la cantidad de tokens que se pueden reclamar
        #[external(v0)]
        fn claim_amount(self: @ContractState) -> u256 {
            CLAIM_AMOUNT
        }
    }
}
