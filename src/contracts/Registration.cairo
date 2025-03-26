pub mod Registration {
    use core::starknet::{
        ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash,
        contract_address_const,
    };


    use crate::base::types::{Course, Creator};

    pub fn update_creator_info(
        owner_: ContractAddress,
        current_identifier: u256,
        course_ipfs_uri: ByteArray,
        accessment_: bool,
        base_uri: ByteArray,
        mut current_creator_info: Creator
    ) -> (Course, Creator) {
        if current_creator_info.number_of_courses > 0 {
            assert(owner_ == get_caller_address(), 'not owner');
            current_creator_info.number_of_courses += 1;
        } else {
            current_creator_info.address = owner_;
            current_creator_info.number_of_courses += 1;
            current_creator_info.creator_status = true;
        }
        let mut course_call_data: Course = Course {
            owner: owner_,
            course_identifier: current_identifier,
            accessment: accessment_,
            uri: base_uri.clone(),
            course_ipfs_uri: course_ipfs_uri.clone(),
            is_suspended: false,
        };

        return (course_call_data, current_creator_info);
    }

    pub fn deploy_nft_contract(
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        current_identifier: u256,
        hash: ClassHash
    ) -> ContractAddress {
        // constructor arguments
        let mut constructor_args = array![];
        base_uri.serialize(ref constructor_args);
        name_.serialize(ref constructor_args);
        symbol.serialize(ref constructor_args);
        let contract_address_salt: felt252 = current_identifier.try_into().unwrap();

        //deploy contract
        let (deployed_contract_address, _) = deploy_syscall(
            hash, contract_address_salt, constructor_args.span(), false,
        )
            .expect('failed to deploy_syscall');

        deployed_contract_address
    }
}
