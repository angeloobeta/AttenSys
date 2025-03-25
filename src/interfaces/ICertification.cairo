use core::starknet::ContractAddress;
use crate::base::types::{Course, Creator};

#[starknet::interface]
pub trait ICertification<TContractState> {
    fn finish_course_claim_certification(ref self: TContractState, course_identifier: u256);
    fn check_course_completion_status_n_certification(
        self: @TContractState, course_identifier: u256, candidate: ContractAddress,
    ) -> bool;
    fn is_user_certified_for_course(
        self: @TContractState, user: ContractAddress, course_id: u256
    ) -> bool;
    fn get_user_completed_courses(self: @TContractState, user: ContractAddress) -> Array<u256>;
    fn get_total_course_completions(self: @TContractState, course_identifier: u256) -> u256;
    fn get_course_nft_contract(self: @TContractState, course_identifier: u256) -> ContractAddress;
}
