use starknet::{ContractAddress, contract_address_const,};
// get_caller_address,
use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address,start_cheat_block_timestamp_global};



// use attendsys::AttenSys::IAttenSysSafeDispatcher;
// use attendsys::AttenSys::IAttenSysSafeDispatcherTrait;
use attendsys::contracts::AttenSysCourse::IAttenSysCourseDispatcher;
use attendsys::contracts::AttenSysCourse::IAttenSysCourseDispatcherTrait;

use attendsys::contracts::AttenSysEvent::IAttenSysEventDispatcher;
use attendsys::contracts::AttenSysEvent::IAttenSysEventDispatcherTrait;


#[starknet::interface]
pub trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TContractState, owner: ContractAddress, operator: ContractAddress) -> bool;

    // IERC721Metadata
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;

    // NFT contract
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'contract_owner_address'>();
    constuctor_arg.append(contract_owner_address.into());
    let (contract_address, _) = contract.deploy(@constuctor_arg).unwrap();
    contract_address
}

fn deploy_nft_contract(name: ByteArray) -> ContractAddress {
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let mut constructor_calldata: Array<felt252> = ArrayTrait::new();
    token_uri.serialize(ref constructor_calldata);

    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    
    contract_address
}



#[test]
fn test_create_course() {
    let contract_address = deploy_contract("AttenSysCourse");
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysCourseDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_course(owner_address, true);
    //call again
    dispatcher.create_course(owner_address, true);
    let creator_courses = dispatcher.get_all_creator_courses(owner_address);
    let creator_info = dispatcher.get_creator_info(owner_address);

    let array_calldata = array![1, 2];
    let course_info = dispatcher.get_course_infos(array_calldata);
    assert(creator_courses.len() == 2, 'wrong count');
    assert(*creator_courses.at(0).owner == owner_address, 'wrong owner');
    assert(*creator_courses.at(1).owner == owner_address, 'wrong owner');
    assert(creator_info.creator_status == true, 'failed not creator');
    assert(course_info.len() == 2, 'get course fail');
}

#[test]
fn test_add_replace_course_content() {
    let contract_address = deploy_contract("AttenSysCourse");
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysCourseDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_course(owner_address, true);
    dispatcher.add_replace_course_content(1, owner_address, '123', '567');
    let array_calldata = array![1];
    let course_info = dispatcher.get_course_infos(array_calldata);
    assert(*course_info.at(0).uri.first == '123', 'wrong first uri');
    assert(*course_info.at(0).uri.second == '567', 'wrong second uri');

    let second_array_calldata = array![1];
    dispatcher.add_replace_course_content(1, owner_address, '555', '666');
    let course_info = dispatcher.get_course_infos(second_array_calldata);
    assert(*course_info.at(0).uri.first == '555', 'wrong first uri');
    assert(*course_info.at(0).uri.second == '666', 'wrong second uri');

    let all_courses_info = dispatcher.get_all_courses_info();
    assert(all_courses_info.len() > 0, 'non-write');
    assert(*all_courses_info.at(0).uri.first == '555', 'wrong uri replacement');
    assert(*all_courses_info.at(0).uri.second == '666', 'wrong uri replacement');

    let all_creator_courses = dispatcher.get_all_creator_courses(owner_address);
    assert(all_creator_courses.len() > 0, 'non write CC');
}

#[test]
fn test_create_event() {
    let contract_address = deploy_contract("AttenSysEvent");
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let owner_address_two: ContractAddress = contract_address_const::<'owner_two'>();
    let dispatcher = IAttenSysEventDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let event_name: ByteArray = "web3";
    dispatcher.create_event(owner_address, event_name.clone(), 2238493, 32989989, true);
    let event_details_check = dispatcher.get_event_details(1);
    assert(event_details_check.event_name == event_name, 'wrong_name');
    assert(event_details_check.time.registration_open == true, 'not set');
    assert(event_details_check.time.start_time == 2238493, 'wrong start');
    assert(event_details_check.time.end_time == 32989989, 'wrong end');
    assert(event_details_check.event_organizer == owner_address, 'wrong owner');

    start_cheat_caller_address(contract_address, owner_address_two);
    let event_name_two: ByteArray = "web2";
    dispatcher.create_event(owner_address_two, event_name_two.clone(), 2238493, 32989989, true);

    let event_details_check_two = dispatcher.get_event_details(2);
    assert(event_details_check_two.event_name == event_name_two, 'wrong_name');
}

#[test]
fn test_reg_nd_mark() {
    let contract_address = deploy_contract("AttenSysEvent");
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let attendee1_address: ContractAddress = contract_address_const::<'attendee1_address'>();
    let attendee2_address: ContractAddress = contract_address_const::<'attendee2_address'>();
    let attendee3_address: ContractAddress = contract_address_const::<'attendee3_address'>();

    let dispatcher = IAttenSysEventDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let event_name: ByteArray = "web3";
    dispatcher.create_event(owner_address, event_name.clone(), 223, 329, true);

    start_cheat_block_timestamp_global(55555);
    start_cheat_caller_address(contract_address, attendee1_address);
    dispatcher.register_for_event(1);
    dispatcher.mark_attendance(1);
    let all_events = dispatcher.get_all_attended_events(attendee1_address);
    assert(all_events.len() == 1, 'wrong length');

    start_cheat_caller_address(contract_address, attendee2_address);
    dispatcher.register_for_event(1);
    dispatcher.mark_attendance(1);

    start_cheat_caller_address(contract_address, attendee3_address);
    dispatcher.register_for_event(1);
    dispatcher.mark_attendance(1);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.batch_certify_attendees(1);

    let attendance_stat = dispatcher.get_attendance_status(attendee3_address, 1);
    assert(attendance_stat == true, 'wrong attenStat');
}



#[test]
fn test_constructor() {
    let contract_address = deploy_nft_contract("AttenSysNft");

    let erc721_token = IERC721Dispatcher { contract_address };

    let token_name = erc721_token.name();
    let token_symbol = erc721_token.symbol();

    assert(token_name == "Attensys", 'wrong token name');
    assert(token_symbol == "ASC", 'wrong token symbol');
}

#[test]
fn test_mint() {
    let contract_address = deploy_nft_contract("AttenSysNft");

    let erc721_token = IERC721Dispatcher { contract_address };

    let token_recipient: ContractAddress = contract_address_const::<'recipient_address'>();

    erc721_token.mint(token_recipient, 1);

    assert(erc721_token.owner_of(1) == token_recipient, 'wrong token id');
    assert(erc721_token.balance_of(token_recipient) > 0, 'mint failed');
}


