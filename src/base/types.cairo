use starknet::ContractAddress;

#[event]
#[derive(starknet::Event, Clone, Debug, Drop)]
pub enum Event {
    CourseCreated: CourseCreated,
    CourseReplaced: CourseReplaced,
    CourseCertClaimed: CourseCertClaimed,
    AdminTransferred: AdminTransferred,
    CourseSuspended: CourseSuspended,
    CourseUnsuspended: CourseUnsuspended,
}


#[derive(starknet::Event, Clone, Debug, Drop)]
pub struct CourseCreated {
    pub course_identifier: u256,
    pub owner_: ContractAddress,
    pub accessment_: bool,
    pub base_uri: ByteArray,
    pub name_: ByteArray,
    pub symbol: ByteArray,
    pub course_ipfs_uri: ByteArray,
}

#[derive(starknet::Event, Clone, Debug, Drop)]
pub struct CourseReplaced {
    pub course_identifier: u256,
    pub owner_: ContractAddress,
    pub new_course_uri: ByteArray,
}

#[derive(starknet::Event, Clone, Debug, Drop)]
pub struct CourseCertClaimed {
    pub course_identifier: u256,
    pub candidate: ContractAddress,
}

#[derive(starknet::Event, Clone, Debug, Drop)]
pub struct AdminTransferred {
    pub new_admin: ContractAddress,
}

#[derive(starknet::Event, Clone, Debug, Drop)]
pub struct CourseSuspended {
    course_identifier: u256,
}

#[derive(starknet::Event, Clone, Debug, Drop)]
pub struct CourseUnsuspended {
    course_identifier: u256,
}
#[derive(Drop, Serde, starknet::Store)]
pub struct Creator1 {
    pub address: ContractAddress,
    pub number_of_courses: u256,
    pub creator_status: bool,
}

//consider the idea of having the uri for each course within the course struct.

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