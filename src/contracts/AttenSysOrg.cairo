use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: ByteArray, org_ipfs_uri: ByteArray);
    fn add_instructor_to_org(ref self: TContractState, instructor: ContractAddress);
    fn create_bootcamp(
        ref self: TContractState,
        org_name: ByteArray,
        bootcamp_name: ByteArray,
        nft_name: ByteArray,
        nft_symbol: ByteArray,
        nft_uri: ByteArray,
        num_of_class_to_create: u256,
        bootcamp_ipfs_uri: ByteArray
    );
    fn add_active_meet_link(ref self: TContractState, meet_link: ByteArray, bootcamp_id: u64,);
    fn register_for_class(
        ref self: TContractState, org_: ContractAddress, instructor_: ContractAddress, class_id: u64
    );
    fn mark_attendance_for_a_class(
        ref self: TContractState, org_: ContractAddress, instructor_: ContractAddress, class_id: u64
    );
    fn batch_certify_students(
        ref self: TContractState,
        org_: ContractAddress,
        class_id: u64,
        students: Array<ContractAddress>
    );
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
    fn get_student_info(self: @TContractState, student_: ContractAddress) -> AttenSysOrg::Student;
    fn get_student_classes(
        self: @TContractState, student: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
    fn get_instructor_part_of_org(self: @TContractState, instructor: ContractAddress) -> bool;
}

//The contract
#[starknet::contract]
mod AttenSysOrg {
    use core::starknet::{ContractAddress, ClassHash, get_caller_address, syscalls::deploy_syscall};
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
        // save bootcamps of org in an array
        org_to_bootcamps: Map::<ContractAddress, Vec<Bootcamp>>,
        //validate that an instructor is associated to an org
        instructor_part_of_org: Map::<(ContractAddress, ContractAddress), bool>,
        //maps org and instructor to classes
        org_instructor_classes: Map::<(ContractAddress, ContractAddress), Vec<Class>>,
        // track the number of classes a single student has registered for.
        student_to_classes: Map::<ContractAddress, Vec<Class>>,
        // update and retrieve students info
        student_info: Map::<ContractAddress, Student>,
        //saves attendance status of students
        student_attendance_status: Map::<(ContractAddress, u64), bool>,
        //saves attendance status of students
        inst_student_status: Map<ContractAddress, Map<ContractAddress, bool>>,
        //cerified course, student ---> true
        certify_student: Map::<(u64, ContractAddress), bool>,
        //nft classhash
        hash: ClassHash,
    }

    //find a way to keep track of all course identifiers for each owner.
    #[derive(Drop, Serde, starknet::Store)]
    pub struct Organization {
        pub address_of_org: ContractAddress,
        pub org_name: ByteArray,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_classes: u256,
        pub number_of_all_bootcamps: u256,
        pub org_ipfs_uri: ByteArray
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Bootcamp {
        pub address_of_org: ContractAddress,
        pub org_name: ByteArray,
        pub bootcamp_name: ByteArray,
        pub number_of_instructors: u256,
        pub number_of_students: u256,
        pub number_of_all_bootcamp_classes: u256,
        pub nft_address: ContractAddress,
        pub bootcamp_ipfs_uri: ByteArray,
        pub active_meet_link: ByteArray
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Instructor {
        pub address_of_org: ContractAddress,
        pub num_of_classes: u256,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Class {
        pub address_of_org: ContractAddress,
        pub instructor: ContractAddress,
        pub num_of_reg_students: u32,
        pub active_status: bool,
        pub bootcamp_id: u64
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Student {
        pub address_of_student: ContractAddress,
        pub num_of_classes_registered_for: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, class_hash: ClassHash) {
        self.hash.write(class_hash);
    }

    #[abi(embed_v0)]
    impl IAttenSysOrgImpl of super::IAttenSysOrg<ContractState> {
        //ability to create organization profile, each org info should be saved properly, use
        //mappings and structs where necessary
        fn create_org_profile(
            ref self: ContractState, org_name: ByteArray, org_ipfs_uri: ByteArray
        ) {
            //check that the caller address has an organization created before
            let creator = get_caller_address();
            let status: bool = self.created_status.entry(creator).read();
            if !status {
                self.created_status.entry(creator).write(true);

                // create organization and update to an address
                let org_call_data: Organization = Organization {
                    address_of_org: creator,
                    org_name: org_name.clone(),
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_classes: 0,
                    number_of_all_bootcamps: 0,
                    org_ipfs_uri: org_ipfs_uri.clone()
                };

                self.all_org_info.append().write(org_call_data);
                self
                    .organization_info
                    .entry(creator)
                    .write(
                        Organization {
                            address_of_org: creator,
                            org_name: org_name,
                            number_of_instructors: 0,
                            number_of_students: 0,
                            number_of_all_classes: 0,
                            number_of_all_bootcamps: 0,
                            org_ipfs_uri: org_ipfs_uri
                        }
                    );
            } else {
                panic!("created an organization.");
            }
        }
        // add instructor to an organization
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
                    self.organization_info.entry(caller).write(org_call_data);
                } else {
                    panic!("already added.");
                }
            } else {
                panic!("no organization created.");
            }
        }

        fn create_bootcamp(
            ref self: ContractState,
            org_name: ByteArray,
            bootcamp_name: ByteArray,
            nft_name: ByteArray,
            nft_symbol: ByteArray,
            nft_uri: ByteArray,
            num_of_class_to_create: u256,
            bootcamp_ipfs_uri: ByteArray
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if (status) {
                // constructor arguments
                let mut constructor_args = array![];
                nft_uri.serialize(ref constructor_args);
                nft_name.serialize(ref constructor_args);
                nft_symbol.serialize(ref constructor_args);
                //deploy contract
                let contract_address_salt: felt252 = caller.into();
                let (deployed_contract_address, _) = deploy_syscall(
                    self.hash.read(), contract_address_salt, constructor_args.span(), false
                )
                    .expect('failed to deploy_syscall');

                // create bootcamp and update
                let bootcamp_call_data: Bootcamp = Bootcamp {
                    address_of_org: caller,
                    org_name: org_name.clone(),
                    bootcamp_name: bootcamp_name.clone(),
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_bootcamp_classes: num_of_class_to_create,
                    nft_address: deployed_contract_address,
                    bootcamp_ipfs_uri: bootcamp_ipfs_uri.clone(),
                    active_meet_link: ""
                };

                //append into the array of bootcamps associated to an organization
                let index = self.org_to_bootcamps.entry(caller).len();
                self.org_to_bootcamps.entry(caller).append().write(bootcamp_call_data);

                // update the number of bootcamps created in an organization
                let mut org_call_data: Organization = self.organization_info.entry(caller).read();
                org_call_data.number_of_all_bootcamps += 1;
                org_call_data.number_of_all_classes += num_of_class_to_create;
                self.organization_info.entry(caller).write(org_call_data);

                //create classes
                create_a_class(ref self, caller, num_of_class_to_create, index);
            } else {
                panic!("no organization created.");
            }
        }

        fn add_active_meet_link(ref self: ContractState, meet_link: ByteArray, bootcamp_id: u64,) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if (status) {
                let mut bootcamp: Bootcamp = self
                    .org_to_bootcamps
                    .entry(caller)
                    .at(bootcamp_id)
                    .read();
                bootcamp.active_meet_link = meet_link;
            } else {
                panic!("no organization created.");
            };
        }

        fn register_for_class(
            ref self: ContractState,
            org_: ContractAddress,
            instructor_: ContractAddress,
            class_id: u64
        ) {
            let caller = get_caller_address();
            let status: bool = self.instructor_part_of_org.entry((org_, instructor_)).read();
            // check that instructor is associated with an organization
            if status {
                let mut class = self.org_instructor_classes.entry((org_, instructor_));
                let mut num_of_classes_registered_for = self
                    .student_info
                    .entry(caller)
                    .read()
                    .num_of_classes_registered_for;
                //loop all classes of an instructor, if the course id is same as student
                // interested class_id.
                for i in 0
                    ..class
                        .len() {
                            if i == class_id {
                                // if the student has registered for a course before
                                if (num_of_classes_registered_for > 0) {
                                    let mut student: Student = self
                                        .student_info
                                        .entry(caller)
                                        .read();
                                    student
                                        .num_of_classes_registered_for =
                                            num_of_classes_registered_for
                                        + 1;
                                } else {
                                    let student_data: Student = Student {
                                        address_of_student: caller,
                                        num_of_classes_registered_for: 1,
                                    };
                                    self.student_info.entry(caller).write(student_data);
                                }
                                let mut instructor_class = self
                                    .org_instructor_classes
                                    .entry((org_, instructor_))
                                    .at(class_id)
                                    .read();
                                self
                                    .student_to_classes
                                    .entry(caller)
                                    .append()
                                    .write(instructor_class);
                                // update organization and instructor data
                                let mut org = self.organization_info.entry(org_).read();
                                org.number_of_students += 1;
                                self.organization_info.entry(org_).write(org);
                                //update instructor class info
                                instructor_class.num_of_reg_students += 1;
                                self
                                    .org_instructor_classes
                                    .entry((org_, instructor_))
                                    .at(class_id)
                                    .write(instructor_class);
                                self
                                    .inst_student_status
                                    .entry(instructor_)
                                    .entry(caller)
                                    .write(true);
                            }
                        }
                //
            } else {
                panic!("unassociated org N instructor");
            }
        }

        fn mark_attendance_for_a_class(
            ref self: ContractState,
            org_: ContractAddress,
            instructor_: ContractAddress,
            class_id: u64
        ) {
            let caller = get_caller_address();
            let mut instructor_class = self
                .org_instructor_classes
                .entry((org_, instructor_))
                .at(class_id)
                .read();
            let reg_status = self.student_attendance_status.entry((caller, class_id)).read();
            assert(instructor_class.active_status, 'not a class');
            assert(!reg_status, 'not registered student');
            self.student_attendance_status.entry((caller, class_id)).write(true);
        }

        fn batch_certify_students(
            ref self: ContractState,
            org_: ContractAddress,
            class_id: u64,
            students: Array<ContractAddress>
        ) {
            //only instructor under an organization issues certificate
            //all of the registered students with attendance
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            let num_of_reg_student = self
                .org_instructor_classes
                .entry((org_, caller))
                .at(class_id)
                .read()
                .num_of_reg_students;
            assert(is_instructor, 'not an instructor');
            if num_of_reg_student > 0 {
                for i in 0
                    ..num_of_reg_student {
                        if self.inst_student_status.entry(caller).entry(*students.at(i)).read() {
                            self.certify_student.entry((class_id, *students.at(i))).write(true);
                        }
                    }
            }
        }

        // read functions
        fn get_all_org_classes(self: @ContractState, org_: ContractAddress) -> Array<Class> {
            let mut arr_of_org = array![];
            let mut arr_of_instructors = array![];
            let mut arr_of_all_created_classes = array![];

            for i in 0
                ..self
                    .all_org_info
                    .len() {
                        // let i_u32: u32 = i.try_into().unwrap();
                        arr_of_org.append(self.all_org_info.at(i).read());
                        let i_u32: u32 = i.try_into().unwrap();

                        for j in 0
                            ..self
                                .org_to_instructors
                                .entry(*arr_of_org.at(i_u32).address_of_org)
                                .len() {
                                    let j_u32: u32 = j.try_into().unwrap();
                                    arr_of_instructors
                                        .append(
                                            self
                                                .org_to_instructors
                                                .entry(*arr_of_org.at(i_u32).address_of_org)
                                                .at(j)
                                                .read()
                                        );

                                    for k in 0
                                        ..self
                                            .org_instructor_classes
                                            .entry(
                                                (
                                                    *arr_of_org.at(i_u32).address_of_org,
                                                    *arr_of_instructors.at(j_u32).address_of_org
                                                )
                                            )
                                            .len() {
                                                arr_of_all_created_classes
                                                    .append(
                                                        self
                                                            .org_instructor_classes
                                                            .entry(
                                                                (
                                                                    *arr_of_org
                                                                        .at(i_u32)
                                                                        .address_of_org,
                                                                    *arr_of_instructors
                                                                        .at(j_u32)
                                                                        .address_of_org
                                                                )
                                                            )
                                                            .at(k)
                                                            .read()
                                                    );
                                            }
                                }
                    };

            arr_of_all_created_classes
        }

        fn get_student_classes(self: @ContractState, student: ContractAddress) -> Array<Class> {
            let mut arr = array![];
            for i in 0
                ..self
                    .student_to_classes
                    .entry(student)
                    .len() {
                        arr.append(self.student_to_classes.entry(student).at(i).read());
                    };
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

        // each orgnization/school should have info for instructors, & students
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

        fn get_student_info(self: @ContractState, student_: ContractAddress) -> Student {
            let mut student_info: Student = self.student_info.entry(student_).read();
            student_info
        }

        fn get_instructor_part_of_org(self: @ContractState, instructor: ContractAddress) -> bool {
            let creator = get_caller_address();
            let isTrue = self.instructor_part_of_org.entry((creator, instructor)).read();
            return isTrue;
        }
    }

    fn create_a_class(
        ref self: ContractState,
        org_: ContractAddress,
        num_of_class_to_create: u256,
        bootcamp_id: u64
    ) {
        let caller = get_caller_address();
        let status: bool = self.instructor_part_of_org.entry((org_, caller)).read();
        // check if an instructor is associated to an organization
        if status {
            let class_data: Class = Class {
                address_of_org: org_,
                instructor: caller,
                num_of_reg_students: 0,
                active_status: true,
                bootcamp_id: bootcamp_id
            };
            // update the org_instructor to classes created
            self.org_instructor_classes.entry((org_, caller)).append().write(class_data);
            // update all general classes linked to org
            let mut org: Organization = self.organization_info.entry(org_).read();
            org.number_of_all_classes += num_of_class_to_create;
            self.organization_info.entry(org_).write(org);
        } else {
            panic!("not an instructor in this org");
        }
    }
}
