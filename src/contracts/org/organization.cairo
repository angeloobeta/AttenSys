use core::starknet::{ContractAddress, get_caller_address};
use core::ByteArray;

#[starknet::interface]
pub trait IOrganizationManagement<TContractState> {
    // Organization-related function signatures
    fn create_org_profile(
        ref self: TContractState, 
        org_name: ByteArray, 
        org_ipfs_uri: ByteArray
    );
    
    fn get_org_info(
        self: @TContractState, 
        org_: ContractAddress
    ) -> Organization;
    
    fn get_all_org_info(
        self: @TContractState) -> Array<Organization>;

    
    fn suspend_organization(
        ref self: TContractState, 
        org_: ContractAddress, 
        suspend: bool
    );
    
    fn is_org_suspended(
        self: @TContractState, 
        org_: ContractAddress
    ) -> bool;

    fn get_instructor_part_of_org(
        self: @TContractState, 
        instructor: ContractAddress) -> bool;

    fn get_org_instructors(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<AttenSysOrg::Instructor>;

    fn add_instructor_to_org(
        ref self: TContractState, 
        instructor: Array<ContractAddress>, 
        org_name: ByteArray,
    );

    fn remove_instructor_from_org(
        ref self: TContractState, 
        instructor: ContractAddress);
   
    
}

// Organization struct from the original contract
#[derive(Drop, Serde, starknet::Store)]
pub struct Organization {
    pub address_of_org: ContractAddress,
    pub org_name: ByteArray,
    pub number_of_instructors: u256,
    pub number_of_students: u256,
    pub number_of_all_classes: u256,
    pub number_of_all_bootcamps: u256,
    pub org_ipfs_uri: ByteArray,
    pub total_sponsorship_fund: u256,
}

// Organization-related events
#[derive(Drop, starknet::Event)]
pub enum OrganizationEvent {
    OrganizationProfile: OrganizationProfile,
    OrganizationSuspended: OrganizationSuspended,
}

#[derive(Drop, starknet::Event)]
pub struct OrganizationProfile {
    pub org_name: ByteArray,
    pub org_ipfs_uri: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct OrganizationSuspended {
    #[key]
    pub org_address: ContractAddress,
    pub suspension_status: bool,
}

// Implementation of organization management logic
#[starknet::contract]
pub mod OrganizationManagement {
    use super::*;
    use starknet::storage::{Map, Vec, VecTrait, MutableVecTrait};

    #[storage]
    struct Storage {
        // Storage mappings related to organizations
        organization_info: Map::<ContractAddress, Organization>,
        all_org_info: Vec<Organization>,
        created_status: Map::<ContractAddress, bool>,
        org_suspended: Map::<ContractAddress, bool>,
    }

    #[generate_trait]
    impl OrganizationImpl of OrganizationTrait {
        // Implementation of organization-related functions
        fn create_org_profile(
            ref self: ContractState, 
            org_name: ByteArray, 
            org_ipfs_uri: ByteArray
        ) {
            let caller = get_caller_address();
            
            // Check if organization already exists
            assert!(!self.created_status.read(caller), 'Organization already exists');
            
            // Create organization struct
            let org = Organization {
                address_of_org: caller,
                org_name,
                number_of_instructors: 0,
                number_of_students: 0,
                number_of_all_classes: 0,
                number_of_all_bootcamps: 0,
                org_ipfs_uri,
                total_sponsorship_fund: 0,
            };
            
            // Store organization info
            self.organization_info.write(caller, org);
            self.all_org_info.append(org);
            self.created_status.write(caller, true);
            
            // Emit event
            self.emit(OrganizationEvent::OrganizationProfile(
                OrganizationProfile {
                    org_name,
                    org_ipfs_uri,
                }
            ));
        }
        
        fn get_org_info(
            self: @ContractState, 
            org_: ContractAddress
        ) -> Organization {
            self.organization_info.read(org_)
        }
        
        fn get_all_org_info(self: @ContractState) -> Array<Organization> {
            let mut result = array![];
            let len = self.all_org_info.len();
            
            let mut i = 0;
            while i < len {
                result.append(self.all_org_info.get(i).unwrap());
                i += 1;
            }
            
            result
        }
        
        fn suspend_organization(
            ref self: ContractState, 
            org_: ContractAddress, 
            suspend: bool
        ) {
            // Add authorization check if needed
            self.org_suspended.write(org_, suspend);
            
            // Emit suspension event
            self.emit(OrganizationEvent::OrganizationSuspended(
                OrganizationSuspended {
                    org_address: org_,
                    suspension_status: suspend,
                }
            ));
        }
        
        fn is_org_suspended(
            self: @ContractState, 
            org_: ContractAddress
        ) -> bool {
            self.org_suspended.read(org_)
        }
    }
}