use starknet::{ContractAddress, contract_address_const,};
// get_caller_address,
use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address};

// use attendsys::AttenSys::IAttenSysSafeDispatcher;
// use attendsys::AttenSys::IAttenSysSafeDispatcherTrait;
use attendsys::AttenSysCourse::IAttenSysCourseDispatcher;
use attendsys::AttenSysCourse::IAttenSysCourseDispatcherTrait;


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_create_course() {
    let contract_address = deploy_contract("AttenSysCourse");
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysCourseDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_course(owner_address,true);
//call again
    dispatcher.create_course(owner_address,true);
    let creator_courses = dispatcher.get_all_creator_courses(owner_address);
    let creator_info = dispatcher.get_creator_info(owner_address);
    
    let array_calldata = array![1,2];
    let course_info = dispatcher.get_course_infos(array_calldata);
    assert(creator_courses.len() == 2, 'wrong count');
    assert(*creator_courses.at(0).owner == owner_address, 'wrong owner');
    assert(*creator_courses.at(1).owner == owner_address, 'wrong owner');
    assert(creator_info.creator_status == true, 'failed not creator');
    assert(course_info.len() == 2, 'get course fail');
}

#[test]
fn test_add_replace_course_content(){
    let contract_address = deploy_contract("AttenSysCourse");
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysCourseDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_course(owner_address,true);
    dispatcher.add_replace_course_content(1,owner_address,'123','567');
    let array_calldata = array![1];
    let course_info = dispatcher.get_course_infos(array_calldata);
    assert(*course_info.at(0).uri.first == '123', 'wrong first uri');
    assert(*course_info.at(0).uri.second == '567', 'wrong second uri');

    let second_array_calldata = array![1];
    dispatcher.add_replace_course_content(1,owner_address,'555','666');
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

