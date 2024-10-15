use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn create_org_profile(ref self: TContractState, org_name: felt252);
    fn add_instructor_to_org(ref self: TContractState, instructor: ContractAddress);
    fn create_a_class(ref self: TContractState, org_: ContractAddress);
    fn register_for_class(
        ref self: TContractState, org_: ContractAddress, instructor_: ContractAddress, class_id: u64
    );
    fn mark_attendance_for_a_class(
        ref self: TContractState, org_: ContractAddress, instructor_: ContractAddress, class_id: u64
    );
    fn batch_certify_students(ref self: TContractState, org_: ContractAddress, class_id: u64, students: Array<ContractAddress>);
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
    fn retrieve_all_class_of_instructors(
        self: @TContractState, org_: ContractAddress, instructor: Array<ContractAddress>
    ) -> Array<AttenSysOrg::Class>;
    fn get_student_classes(
        self: @TContractState, student: ContractAddress
    ) -> Array<AttenSysOrg::Class>;
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
        certify_student: Map::<(u64, ContractAddress), bool>
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

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Class {
        pub address_of_org: ContractAddress,
        pub instructor: ContractAddress,
        pub num_of_reg_students: u32,
        pub active_status: bool,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Student {
        pub address_of_student: ContractAddress,
        pub num_of_classes_registered_for: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {}

    #[abi(embed_v0)]
    impl IAttenSysOrgImpl of super::IAttenSysOrg<ContractState> {
        //ability to create organization profile, each org info should be saved properly, use
        //mappings and structs where necessary
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
                    address_of_org: org_,
                    instructor: caller,
                    num_of_reg_students: 0,
                    active_status: true,
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
                                //update instructor class info
                                instructor_class.num_of_reg_students += 1;
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

        fn batch_certify_students(ref self: ContractState, org_: ContractAddress, class_id: u64, students: Array<ContractAddress>) {
            //only instructor under an organization issues certificate
            //all of the registered students with attendance
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            let num_of_reg_student = self.org_instructor_classes
            .entry((org_, caller))
            .at(class_id)
            .read().num_of_reg_students;
            assert(is_instructor, 'not an instructor');
            if num_of_reg_student > 0 {
                for i in 0..num_of_reg_student {
                    if self
                    .inst_student_status
                    .entry(caller)
                    .entry(*students.at(i))
                    .read() {
                        self.certify_student.entry((class_id, *students.at(i))).write(true);
                    }
                }
            }
        }

        // read functions
        fn get_all_org_classes(self: @ContractState, org_: ContractAddress) -> Array<Class> {
            // get the organization and instructors
            // get the classes created by an instructor under an organ
            // then add these array of classes to the local arr
            //currently rverts due to data type of J being u256.
            //@todo retrieve all classes from providing just the org address

            // let mut arr_of_instructor = array![];
            let mut arr = array![];

            // let mut org: Organization = self.organization_info.entry(org_).read();
            // // let num_of_instructors = org.number_of_instructors;
            // // let number_of_all_classes = org.number_of_all_classes;

            arr
        }

        fn retrieve_all_class_of_instructors(
            self: @ContractState, org_: ContractAddress, instructor: Array<ContractAddress>
        ) -> Array<Class> {
            // let len: u32 = instructor.len().try_into().unwrap();
            let mut arr = array![];
            // let mut i: u32 = 0;
            // let mut j: u32 = 0;

            // loop {
            //     if i >= len {
            //         break;
            //     }
            //     if let element = self
            //         .org_instructor_classes
            //         .entry(org_, instructor.get(i))
            //          {
            //         arr.append(element);
            //         i += 1;
            //         j += 1;
            //     };
            // };
            //@todo retrieve all classes from providing an array of instructors
            arr
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
    }
}
