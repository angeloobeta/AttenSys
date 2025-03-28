use core::starknet::ContractAddress;
use crate::base::types::{Course, Creator};

//to do : return the nft id and token uri in the get function
#[starknet::interface]
pub trait IAttenSysCourse<TContractState> {
    fn create_course(
        ref self: TContractState,
        owner_: ContractAddress,
        accessment_: bool,
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        course_ipfs_uri: ByteArray,
    ) -> (ContractAddress, u256);
    fn add_replace_course_content(
        ref self: TContractState,
        course_identifier: u256,
        owner_: ContractAddress,
        new_course_uri: ByteArray
    );
    fn acquire_a_course(ref self: TContractState, course_identifier: u256);
    //untested
    fn finish_course_claim_certification(ref self: TContractState, course_identifier: u256);
    //untested
    fn check_course_completion_status_n_certification(
        self: @TContractState, course_identifier: u256, candidate: ContractAddress,
    ) -> bool;
    fn get_course_infos(self: @TContractState, course_identifiers: Array<u256>,) -> Array<Course>;
    fn is_user_taking_course(self: @TContractState, user: ContractAddress, course_id: u256) -> bool;
    fn is_user_certified_for_course(
        self: @TContractState, user: ContractAddress, course_id: u256
    ) -> bool;
    fn get_all_taken_courses(self: @TContractState, user: ContractAddress) -> Array<Course>;
    fn get_user_completed_courses(self: @TContractState, user: ContractAddress) -> Array<u256>;
    fn get_all_courses_info(self: @TContractState) -> Array<Course>;
    fn get_all_creator_courses(self: @TContractState, owner_: ContractAddress,) -> Array<Course>;
    fn get_creator_info(self: @TContractState, creator: ContractAddress) -> Creator;
    fn get_course_nft_contract(self: @TContractState, course_identifier: u256) -> ContractAddress;
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
    fn get_total_course_completions(self: @TContractState, course_identifier: u256) -> u256;
    fn ensure_admin(self: @TContractState);
    fn get_suspension_status(self: @TContractState, course_identifier: u256) -> bool;
    fn toggle_suspension(ref self: TContractState, course_identifier: u256, suspend: bool);
}
// use crate::interfaces::IAttenSysCourse;
// use crate::base:types::{Event, CourseCreated, CourseReplaced, CourseCertClaimed,
// AdminTransferred, CourseSuspended, };
//to do : return the nft id and token uri in the get function

// use crate::base:types::{Event, CourseCreated, CourseReplaced, CourseCertClaimed,
// AdminTransferred, CourseSuspended, CourseUnsuspended};


