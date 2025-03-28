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


    fn get_registered_bootcamp(
        self: @TContractState, student: ContractAddress
    ) -> Array<AttenSysOrg::RegisteredBootcamp>;
    
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

    fn get_all_bootcamps_on_platform(
        self: @TContractState) -> Array<AttenSysOrg::Bootcamp>;

    fn add_active_meet_link(
        ref self: TContractState,
        meet_link: ByteArray,
        bootcamp_id: u64,
        is_instructor: bool,
        org_address: ContractAddress,
    );

    fn get_bootcamp_active_meet_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> ByteArray;

    fn get_bootcamp_uploaded_video_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Array<ByteArray>;

    fn get_all_registration_request(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<AttenSysOrg::Student>;

    fn get_all_org_bootcamps(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<AttenSysOrg::Bootcamp>;

    fn get_bootcamp_info(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> AttenSysOrg::Bootcamp;

    fn is_bootcamp_suspended(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> bool;


    fn suspend_org_bootcamp(
        ref self: TContractState, org_: ContractAddress, bootcamp_id_: u64, suspend: bool,
    );
    
}

// Bootcamp struct from the original contract
#[derive(Drop, Serde, starknet::Store)]
pub struct Bootcamp {
    pub bootcamp_id: u64,
    pub address_of_org: ContractAddress,
    pub org_name: ByteArray,
    pub bootcamp_name: ByteArray,
    pub number_of_instructors: u256,
    pub number_of_students: u256,
    pub number_of_all_bootcamp_classes: u256,
    pub nft_address: ContractAddress,
    pub bootcamp_ipfs_uri: ByteArray,
    pub active_meet_link: ByteArray,
}

// Registered Bootcamp struct
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct RegisteredBootcamp {
    pub address_of_org: ContractAddress,
    pub student: ContractAddress,
    pub acceptance_status: bool,
    pub bootcamp_id: u64,
}

// Bootcamp-related events
#[derive(Drop, starknet::Event)]
pub enum BootcampEvent {
    BootCampCreated: BootCampCreated,
    BootcampRegistration: BootcampRegistration,
    RegistrationApproved: RegistrationApproved,
    RegistrationDeclined: RegistrationDeclined,
    BootCampSuspended: BootCampSuspended,
}

#[derive(Drop, starknet::Event)]
pub struct BootCampCreated {
    pub org_name: ByteArray,
    pub bootcamp_name: ByteArray,
    pub nft_name: ByteArray,
    pub nft_symbol: ByteArray,
    pub nft_uri: ByteArray,
    pub num_of_classes: u256,
    pub bootcamp_ipfs_uri: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct BootcampRegistration {
    pub org_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RegistrationApproved {
    pub student_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RegistrationDeclined {
    pub student_address: ContractAddress,
    pub bootcamp_id: u64,
}

#[derive(Drop, starknet::Event)]
pub struct BootCampSuspended {
    #[key]
    pub org_address: ContractAddress,
    pub bootcamp_id: u64,
    pub suspension_status: bool,
}

// Implementation of bootcamp management logic
#[starknet::contract]
pub mod BootcampManagement {
    use super::*;
    use starknet::storage::{Map, Vec, VecTrait, MutableVecTrait};
    use core::starknet::get_caller_address;

    #[storage]
    struct Storage {
        // Bootcamp-related storage mappings
        all_bootcamps_created: Vec<Bootcamp>,
        org_to_bootcamps: Map::<ContractAddress, Vec<Bootcamp>>,
        student_address_to_bootcamps: Map::<ContractAddress, Vec<RegisteredBootcamp>>,
        student_address_to_specific_bootcamp: Map::<(ContractAddress, ContractAddress), Vec<RegisteredBootcamp>>,
        bootcamp_suspended: Map::<ContractAddress, Map<u64, bool>>,
        org_to_requests: Map<ContractAddress, Vec<Student>>,
    }

    #[generate_trait]
    impl BootcampImpl of BootcampTrait {
        fn create_bootcamp(
            ref self: ContractState,
            org_name: ByteArray,
            bootcamp_name: ByteArray,
            nft_name: ByteArray,
            nft_symbol: ByteArray,
            nft_uri: ByteArray,
            num_of_class_to_create: u256,
            bootcamp_ipfs_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            
            // Generate unique bootcamp ID (simplified example)
            let bootcamp_id = self.all_bootcamps_created.len().try_into().unwrap();
            
            // Create bootcamp struct
            let bootcamp = Bootcamp {
                bootcamp_id,
                address_of_org: caller,
                org_name,
                bootcamp_name,
                number_of_instructors: 0,
                number_of_students: 0,
                number_of_all_bootcamp_classes: num_of_class_to_create,
                nft_address: contract_address_const::<0>(), // Placeholder
                bootcamp_ipfs_uri,
                active_meet_link: ByteArray::new(),
            };
            
            // Store bootcamp information
            self.all_bootcamps_created.append(bootcamp);
            
            // Add to organization's bootcamps
            let mut org_bootcamps = self.org_to_bootcamps.read(caller);
            org_bootcamps.append(bootcamp);
            self.org_to_bootcamps.write(caller, org_bootcamps);
            
            // Emit event
            self.emit(BootcampEvent::BootCampCreated(
                BootCampCreated {
                    org_name,
                    bootcamp_name,
                    nft_name,
                    nft_symbol,
                    nft_uri,
                    num_of_classes: num_of_class_to_create,
                    bootcamp_ipfs_uri,
                }
            ));
        }
        
        fn register_for_bootcamp(
            ref self: ContractState, 
            org_: ContractAddress, 
            bootcamp_id: u64, 
            student_uri: ByteArray
        ) {
            let caller = get_caller_address();
            
            // Create registered bootcamp entry
            let registered_bootcamp = RegisteredBootcamp {
                address_of_org: org_,
                student: caller,
                acceptance_status: false,
                bootcamp_id,
            };
            
            // Add to registration requests
            let mut org_requests = self.org_to_requests.read(org_);
            
            // Add student to registration requests (you might want to add more validation)
            let student = Student {
                address_of_student: caller,
                num_of_bootcamps_registered_for: 1,
                status: 0, // Default status
                student_details_uri: student_uri,
            };
            org_requests.append(student);
            self.org_to_requests.write(org_, org_requests);
            
            // Emit registration event
            self.emit(BootcampEvent::BootcampRegistration(
                BootcampRegistration {
                    org_address: org_,
                    bootcamp_id,
                }
            ));
        }
        
        fn approve_registration(
            ref self: ContractState, 
            student_address: ContractAddress, 
            bootcamp_id: u64
        ) {
            let caller = get_caller_address();
            
            // Update student's registered bootcamps
            let mut student_bootcamps = self.student_address_to_bootcamps.read(student_address);
            let mut student_specific_bootcamps = self.student_address_to_specific_bootcamp
                .read((caller, student_address));
            
            // Create approved registration
            let registered_bootcamp = RegisteredBootcamp {
                address_of_org: caller,
                student: student_address,
                acceptance_status: true,
                bootcamp_id,
            };
            
            student_bootcamps.append(registered_bootcamp);
            student_specific_bootcamps.append(registered_bootcamp);
            
            // Update storage
            self.student_address_to_bootcamps.write(student_address, student_bootcamps);
            self.student_address_to_specific_bootcamp
                .write((caller, student_address), student_specific_bootcamps);
            
            // Emit approval event
            self.emit(BootcampEvent::RegistrationApproved(
                RegistrationApproved {
                    student_address,
                    bootcamp_id,
                }
            ));
        }
        
        fn decline_registration(
            ref self: ContractState, 
            student_address: ContractAddress, 
            bootcamp_id: u64
        ) {
            let caller = get_caller_address();
            
            // Emit decline event
            self.emit(BootcampEvent::RegistrationDeclined(
                RegistrationDeclined {
                    student_address,
                    bootcamp_id,
                }
            ));
        }
        
        fn get_bootcamp_info(
            self: @ContractState, 
            org_: ContractAddress, 
            bootcamp_id: u64
        ) -> Bootcamp {
            // Find and return bootcamp info
            let bootcamps = self.org_to_bootcamps.read(org_);
            bootcamps.get(bootcamp_id.try_into().unwrap()).unwrap()
        }
        
        fn get_all_org_bootcamps(
            self: @ContractState, 
            org_: ContractAddress
        ) -> Array<Bootcamp> {
            let bootcamps = self.org_to_bootcamps.read(org_);
            let mut result = array![];
            
            let len = bootcamps.len();
            let mut i = 0;
            while i < len {
                result.append(bootcamps.get(i).unwrap());
                i += 1;
            }
            
            result
        }
        
        fn get_all_bootcamps_on_platform(
            self: @ContractState
        ) -> Array<Bootcamp> {
            let mut result = array![];
            let len = self.all_bootcamps_created.len();
            
            let mut i = 0;
            while i < len {
                result.append(self.all_bootcamps_created.get(i).unwrap());
                i += 1;
            }
            
            result
        }
        
        fn suspend_org_bootcamp(
            ref self: ContractState, 
            org_: ContractAddress, 
            bootcamp_id_: u64, 
            suspend: bool
        ) {
            // Update bootcamp suspension status
            self.bootcamp_suspended.write(org_, bootcamp_id_, suspend);
            
            // Emit suspension event
            self.emit(BootcampEvent::BootCampSuspended(
                BootCampSuspended {
                    org_address: org_,
                    bootcamp_id: bootcamp_id_,
                    suspension_status: suspend,
                }
            ));
        }
        
        fn is_bootcamp_suspended(
            self: @ContractState, 
            org_: ContractAddress, 
            bootcamp_id: u64
        ) -> bool {
            self.bootcamp_suspended.read(org_).read(bootcamp_id)
        }
    }

    // Temporary Student struct (might be moved to a separate module)
    #[derive(Drop, Serde, starknet::Store)]
    pub struct Student {
        pub address_of_student: ContractAddress,
        pub num_of_bootcamps_registered_for: u256,
        pub status: u8,
        pub student_details_uri: ByteArray,
    }
}