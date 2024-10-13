//CREATE A NEW BRANCH ON THE REPO BASED ON MAIN
//THEN MAKE PR'S FROM THE BRANCH.


//Todo
//ability to create organization profile, each org info should be saved properly, use mappings and structs where necessary
// each orgnization/school should have info for instructors, & students
//abilty for instructors to create class
//ability for students to be able to register for the class
//ability for students to mark attendance for each class attended
//batch issuance of certification by organization owner (rather than subscribing to the use of nft, a simple bool should suffice, NFT's can be introduced in one of the phases)
//read functions for all informatoion saved in storage, for example, organization profile, student profile, instructor profile.
//read function for cetification status of student for a particular course for a particular school (use nested mappings where necessary).
//function to get all registered organization profile
//function to get all classes created within a paticular organzation
// a function to make changes to organization that, like number of classes they intend to create(whether increase or decrease it), or organization name
//function to return all classes registered for by a student
//function to obtain class created by several instructors (let batch return this, like, passin in an array of instructor addresses, to return all classes created)
//Overall, include necessary read functions that would be helpful for smooth frontend integrations.


//organization profile should include, organization owners, total number of students, number of instructors and any other info you deem fit 
//also, in the process of building, include functions you deem fit for the project. 
//in advent of not been able to save arrays in storage, utilize "VEC"
//this is not the final todo, it may be updated has we work along. 
//if You have any questions, please do well to reach out.
//GOD SPEED.


use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: felt252);
    fn add_instructor_to_org(ref self: TContractState, instructor: ContractAddress);
    fn create_a_class(ref self: TContractState, org_: ContractAddress);
    fn get_org_instructors(
        self: @TContractState, org_: ContractAddress
    ) -> Array<AttenSysOrg::Instructor>;
    fn get_all_org_classes(
        self: @TContractState, org_: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
    fn get_instructor_org_classes(
        self: @TContractState, org_: ContractAddress, instructor: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
    fn get_org_info(self: @TContractState, org_: ContractAddress) -> AttenSysOrg::Organization;
    fn get_all_org_info(self: @TContractState) -> Array<AttenSysOrg::Organization>;
}

//The contract
#[starknet::contract]
mod AttenSysOrg {
    use core::starknet::{ContractAddress, get_caller_address};
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
        MutableVecTrait
    };
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        // save an organization profile and return info when needed.
        organization_info: Map::<ContractAddress, Organization>,
        // save all organization info
        all_org_info: Vec<Organization>,
        // status of org creator address
        created_status: Map::<ContractAddress, bool>,
        // save instructors of org in an array
        org_to_instructors: Map::<ContractAddress, Vec<Instructor>>,
        //validate that an instructor is associated to an org
        instructor_part_of_org: Map::<(ContractAddress, ContractAddress), bool>,
        //maps org and instructor to classes
        org_instructor_classes: Map::<(ContractAddress, ContractAddress), Vec<Class>>
    }

    //find a way to keep track of all course identifiers for each owner.
    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Organization {
        pub address_of_org: ContractAddress,
        pub org_name: felt252,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_classes: u256,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Instructor {
        pub address_of_org: ContractAddress,
        pub num_of_classes: u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Class {
        pub address_of_org: ContractAddress,
        pub instructor: ContractAddress,
        pub num_of_reg_students: u256,
    }

    #[abi(embed_v0)]
    impl IAttenSysOrgImpl of super::IAttenSysOrg<ContractState> {
        // organizations can create a profile
        fn create_org_profile(ref self: ContractState, org_name: felt252) {
            //check that the caller address has an organization created before
            let creator = get_caller_address();
            let status: bool = self.created_status.entry(creator).read();
            if !status {
                self.created_status.entry(creator).write(true);

                // create organization and update to an address
                let org_call_data: Organization = Organization {
                    address_of_org: creator,
                    org_name: org_name,
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_classes: 0,
                };
                self.all_org_info.append().write(org_call_data);
                self.organization_info.entry(creator).write(org_call_data);
            } else {
                panic!("created an organization.");
            }
        }
        // organizations can instructor profile
        fn add_instructor_to_org(ref self: ContractState, instructor: ContractAddress) {
            assert(!instructor.is_zero(), 'zero address.');
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                if !self.instructor_part_of_org.entry((caller, instructor)).read() {
                    self.instructor_part_of_org.entry((caller, instructor)).write(true);

                    let mut instructor_data: Instructor = Instructor {
                        address_of_org: instructor, num_of_classes: 0,
                    };
                    self.org_to_instructors.entry(caller).append().write(instructor_data);
                    let mut org_call_data: Organization = self
                        .organization_info
                        .entry(caller)
                        .read();
                    org_call_data.number_of_instructors += 1;
                } else {
                    panic!("already added.");
                }
            } else {
                panic!("no organization created.");
            }
        }

        fn create_a_class(ref self: ContractState, org_: ContractAddress) {
            let caller = get_caller_address();
            let status: bool = self.instructor_part_of_org.entry((org_, caller)).read();
            // check if an instructor is associated to an organization
            if status {
                let class_data: Class = Class {
                    address_of_org: org_, instructor: caller, num_of_reg_students: 0,
                };
                // update the org_instructor to classes created
                self.org_instructor_classes.entry((org_, caller)).append().write(class_data);
                // update all general classes linked to org
                let mut org: Organization = self.organization_info.entry(org_).read();
                org.number_of_all_classes += 1;
            } else {
                panic!("not an instructor in this org");
            }
        }

        // read functions
        fn get_all_org_classes(self: @ContractState, org_: ContractAddress) -> Array<Class> {
            // get the organization and instructors
            // get the classes created by an instructor under an organ
            // then add these array of classes to the local arr
        //@audit-issue currently rverts due to data type of J being u256.

            // let mut arr_of_instructor = array![];
            let mut arr = array![];

            // let mut org: Organization = self.organization_info.entry(org_).read();
            // let num_of_instructors = org.number_of_instructors;
            // let number_of_all_classes = org.number_of_all_classes;

            // // for i in 0
            // //     ..self
            // //         .org_to_instructors
            // //         .entry(org_)
            // //         .len() {
            // //             arr_of_instructor.append(self.org_to_instructors.entry(org_).at(i).read());
            // //         };

            // // for i in 0
            // //     ..num_of_instructors {
            // //         for j in 0
            // //             ..number_of_all_classes {
            // //                 arr
            // //                     .append(
            // //                         self
            // //                             .org_instructor_classes
            // //                             .entry((org_, arr_of_instructor[i]))
            // //                             .at(j)
            // //                             .read()
            // //                     );
            // //             };
            // //     };

            arr
        }

        fn get_instructor_org_classes(
            self: @ContractState, org_: ContractAddress, instructor: ContractAddress
        ) -> Array<Class> {
            let mut arr = array![];
            for i in 0
                ..self
                    .org_instructor_classes
                    .entry((org_, instructor))
                    .len() {
                        arr
                            .append(
                                self.org_instructor_classes.entry((org_, instructor)).at(i).read()
                            );
                    };
            arr
        }

        fn get_org_instructors(self: @ContractState, org_: ContractAddress) -> Array<Instructor> {
            let mut arr = array![];
            for i in 0
                ..self
                    .org_to_instructors
                    .entry(org_)
                    .len() {
                        arr.append(self.org_to_instructors.entry(org_).at(i).read());
                    };
            arr
        }

        fn get_org_info(self: @ContractState, org_: ContractAddress) -> Organization {
            let mut organization_info: Organization = self.organization_info.entry(org_).read();
            organization_info
        }

        fn get_all_org_info(self: @ContractState) -> Array<Organization> {
            let mut arr = array![];
            for i in 0..self.all_org_info.len() {
                arr.append(self.all_org_info.at(i).read());
            };
            arr
        }
    }
}
