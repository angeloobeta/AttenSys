// use starknet::{ContractAddress, contract_address_const, ClassHash};
// // get_caller_address,
// use snforge_std::{
//     declare, ContractClassTrait, start_cheat_caller_address, start_cheat_block_timestamp_global,
//     spy_events, EventSpyAssertionsTrait, test_address
// };

// use attendsys::contracts::AttenSysSponsor::{IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait};

// fn deploy_contract(name: ByteArray, token: bool) -> ContractAddress {
//     let contract = declare(name).unwrap();
//     if !token {
//         let mut constuctor_arg = ArrayTrait::new();
//         let org_address: ContractAddress = contract_address_const::<
//             'contract_owner_address'
//         >();
//         let event_address: ContractAddress = contract_address_const::<
//             'contract_owner_address'
//         >();
    
//         org_address.serialize(ref constuctor_arg);
//         event_address.serialize(ref constuctor_arg);
      
//         let (contract_address, _) = contract.deploy(@constuctor_arg).unwrap();
//         contract_address
//     } else {
//         let (contract_address, _) = contract.deploy().unwrap();
//         contract_address
//     }
    
// }


// #[test]
// fn test_deploy() {
//     let (sponsor_contract_address ) = deploy_contract("AttenSysSponsor", false);
//     let (token_address ) = deploy_contract("ERC20", true);
//     // mock event with test addresses
// }


