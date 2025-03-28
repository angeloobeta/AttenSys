use core::starknet::{ContractAddress};
use core::starknet::storage::{Map, Vec};
use core::num::traits::Zero;


pub mod OrganizationManagement {
    use crate::base::types{
        Organization, Bootcamp, Instructor, Class, Student, RegisteredBootcamp, Bootcampclass
    };

    use core::starknet::{
        ContractAddress, ClassHash, get_caller_address, syscalls::deploy_syscall,
        contract_address_const,
    };


}
