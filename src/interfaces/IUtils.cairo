use core::starknet::ContractAddress;
use crate::base::types::Course;

#[starknet::interface]
pub trait IUtils<TContractState> {
    fn is_user_taking_course(self: @TContractState, user: ContractAddress, course_id: u256) -> bool;
    fn get_all_taken_courses(self: @TContractState, user: ContractAddress) -> Array<Course>;
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
    fn ensure_admin(self: @TContractState);
    fn get_suspension_status(self: @TContractState, course_identifier: u256) -> bool;
    fn toggle_suspension(ref self: TContractState, course_identifier: u256, suspend: bool);
}
