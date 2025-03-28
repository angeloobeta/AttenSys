use core::starknet::ContractAddress;
use core::ByteArray;

#[starknet::interface]
pub trait IBootcampManagement<TContractState> {
    // Bootcamp-related function signatures
    fn create_bootcamp(
        ref self: TContractState,
        org_name: ByteArray,
        bootcamp_name: ByteArray,
        nft_name: ByteArray,
        nft_symbol: ByteArray,
        nft_uri: ByteArray,
        num_of_class_to_create: u256,
        bootcamp_ipfs_uri: ByteArray,
    );
    
    fn register_for_bootcamp(
        ref self: TContractState, 
        org_: ContractAddress, 
        bootcamp_id: u64, 
        student_uri: ByteArray
    );
    
    fn approve_registration(
        ref self: TContractState, 
        student_address: ContractAddress, 
        bootcamp_id: u64
    );
    
    fn decline_registration(
        ref self: TContractState, 
        student_address: ContractAddress, 
        bootcamp_id: u64
    );
    
    fn get_bootcamp_info(
        self: @TContractState, 
        org_: ContractAddress, 
        bootcamp_id: u64
    ) -> Bootcamp;
    
    fn get_all_org_bootcamps(
        self: @TContractState, 
        org_: ContractAddress
    ) -> Array<Bootcamp>;
    
    fn get_all_bootcamps_on_platform(
        self: @TContractState
    ) -> Array<Bootcamp>;
    
    fn suspend_org_bootcamp(
        ref self: TContractState, 
        org_: ContractAddress, 
        bootcamp_id_: u64, 
        suspend: bool
    );
    
    fn is_bootcamp_suspended(
        self: @TContractState, 
        org_: ContractAddress, 
        bootcamp_id: u64
    ) -> bool;
}