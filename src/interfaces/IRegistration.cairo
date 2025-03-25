use core::starknet::ContractAddress;
use crate::base::types::{Course, Creator};

//to do : return the nft id and token uri in the get function
#[starknet::interface]
pub trait IRegistration<TContractState> {
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
    fn get_course_infos(self: @TContractState, course_identifiers: Array<u256>,) -> Array<Course>;
    fn get_all_courses_info(self: @TContractState) -> Array<Course>;
    fn get_all_creator_courses(self: @TContractState, owner_: ContractAddress,) -> Array<Course>;
    fn get_creator_info(self: @TContractState, creator: ContractAddress) -> Creator;
}
