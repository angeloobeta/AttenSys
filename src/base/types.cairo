use starknet::ContractAddress;

#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct Course {
    pub owner: ContractAddress,
    pub course_identifier: u256,
    pub accessment: bool,
    pub uri: ByteArray,
    pub course_ipfs_uri: ByteArray,
    pub is_suspended: bool,
}
//   find a way to keep track of all course identifiers for each owner.
#[derive(Drop, Serde, starknet::Store)]
pub struct Creator {
    pub address: ContractAddress,
    pub number_of_courses: u256,
    pub creator_status: bool,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Uri {
    pub first: felt252,
    pub second: felt252,
}
