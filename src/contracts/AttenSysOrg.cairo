use core::starknet::{ContractAddress};

#[starknet::interface]
pub trait IAttenSysOrg<TContractState> {
    fn add_uploaded_video_link(
        ref self: TContractState,
        video_link: ByteArray,
        is_instructor: bool,
        org_address: ContractAddress,
        bootcamp_id: u64,
    );
    fn mark_attendance_for_a_class(
        ref self: TContractState,
        org_: ContractAddress,
        instructor_: ContractAddress,
        class_id: u64,
        bootcamp_id: u64,
    );
    fn batch_certify_students(ref self: TContractState, org_: ContractAddress, bootcamp_id: u64,);
    fn single_certify_student(
        ref self: TContractState, org_: ContractAddress, bootcamp_id: u64, students: ContractAddress
    );
    fn setSponsorShipAddress(ref self: TContractState, sponsor_contract_address: ContractAddress);
    fn sponsor_organization(
        ref self: TContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
    );
    fn withdraw_sponsorship_fund(ref self: TContractState, amt: u256);
    fn suspend_organization(ref self: TContractState, org_: ContractAddress, suspend: bool);
    
    
    
    
    
    fn get_all_org_classes(
        self: @TContractState, org_: ContractAddress,
    ) -> Array<AttenSysOrg::Class>;
    fn get_instructor_org_classes(
        self: @TContractState, org_: ContractAddress, instructor: ContractAddress,
    ) -> Array<AttenSysOrg::Class>;
    //@todo narrow down the student info to specific organization
    fn get_student_info(self: @TContractState, student_: ContractAddress) -> AttenSysOrg::Student;
    fn get_student_classes(
        self: @TContractState, student: ContractAddress,
    ) -> Array<AttenSysOrg::Class>;
    fn get_instructor_info(
        self: @TContractState, instructor: ContractAddress,
    ) -> Array<AttenSysOrg::Instructor>;
   
    fn transfer_admin(ref self: TContractState, new_admin: ContractAddress);
    fn claim_admin_ownership(ref self: TContractState);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_new_admin(self: @TContractState) -> ContractAddress;
    fn get_org_sponsorship_balance(self: @TContractState, organization: ContractAddress) -> u256;
    
    fn get_specific_organization_registered_bootcamp(
        self: @TContractState, org: ContractAddress, student: ContractAddress
    ) -> Array<AttenSysOrg::RegisteredBootcamp>;
    fn get_class_attendance_status(
        self: @TContractState,
        org: ContractAddress,
        bootcamp_id: u64,
        class_id: u64,
        student: ContractAddress
    ) -> bool;
    fn get_all_bootcamp_classes(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<u64>;
    fn get_certified_student_bootcamp_address(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64
    ) -> Array<ContractAddress>;
    fn get_bootcamp_certification_status(
        self: @TContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
    ) -> bool;
}

// Events

//The contract
#[starknet::contract]
pub mod AttenSysOrg {
    use starknet::event::EventEmitter;
    use core::starknet::{
        ContractAddress, ClassHash, get_caller_address, syscalls::deploy_syscall,
        contract_address_const,
    };
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
        MutableVecTrait,
    };
    use core::num::traits::Zero;
    use attendsys::contracts::AttenSysSponsor::IAttenSysSponsorDispatcherTrait;
    use attendsys::contracts::AttenSysSponsor::IAttenSysSponsorDispatcher;


    #[storage]
    struct Storage {
        // save an organization profile and return info when needed.
        organization_info: Map::<ContractAddress, Organization>,
        // save all organization info
        all_org_info: Vec<Organization>,
        // save all bootcamps
        all_bootcamps_created: Vec<Bootcamp>,
        // status of org creator address
        created_status: Map::<ContractAddress, bool>,
        // org to balance_of_sponsorship
        org_to_balance_of_sponsorship: Map::<ContractAddress, u256>,
        // save instructors of org in an array
        org_to_instructors: Map::<ContractAddress, Vec<Instructor>>,
        // save bootcamps of org in an array
        org_to_bootcamps: Map::<ContractAddress, Vec<Bootcamp>>,
        // org to uploaded ipfs video links
        org_to_uploaded_videos_link: Map::<(ContractAddress, u64), Vec<ByteArray>>,
        //validate that an instructor is associated to an org
        instructor_part_of_org: Map::<(ContractAddress, ContractAddress), bool>,
        // instructor as key
        instructor_key_to_info: Map::<ContractAddress, Vec<Instructor>>,
        //maps org and instructor to classes
        org_instructor_classes: Map::<(ContractAddress, ContractAddress), Vec<Class>>,
        // track the number of classes a single student has registered for.
        student_to_classes: Map::<ContractAddress, Vec<Class>>,
        // update and retrieve students info
        student_info: Map::<ContractAddress, Student>,
        //saves attendance status of students
        student_attendance_status: Map::<(ContractAddress, u64, u64, ContractAddress), bool>,
        //saves attendance status of students
        inst_student_status: Map<ContractAddress, Map<ContractAddress, bool>>,
        //cerified course, student ---> true
        certify_student: Map::<(ContractAddress, u64, ContractAddress), bool>,
        //nft classhash
        hash: ClassHash,
        // the currency used on the platform
        token_address: ContractAddress,
        // sponsorship contract address
        sponsorship_contract_address: ContractAddress,
        // AttenSys Admin
        admin: ContractAddress,
        // address of intended new admin
        intended_new_admin: ContractAddress,
        // map org to all requested registration
        org_to_requests: Map<ContractAddress, Vec<Student>>,
        // map org => suspension status
        org_suspended: Map::<ContractAddress, bool>,
        // map org => bootcamp => suspension status
        bootcamp_suspended: Map::<ContractAddress, Map<u64, bool>>,
        //maps student address to vec of bootcamps
        student_address_to_bootcamps: Map::<ContractAddress, Vec<RegisteredBootcamp>>,
        //maps student address to org address to specific bootcamp
        student_address_to_specific_bootcamp: Map::<
            (ContractAddress, ContractAddress), Vec<RegisteredBootcamp>
        >,
        //maps org to bootcamp to classID
        bootcamp_class_data_id: Map::<(ContractAddress, u64), Vec<u64>>,
        //saves all certifed student for each bootcamp
        certified_students_for_bootcamp: Map::<(ContractAddress, u64), Vec<ContractAddress>>,
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
        pub org_ipfs_uri: ByteArray,
        pub total_sponsorship_fund: u256,
    }

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

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Instructor {
        pub address_of_instructor: ContractAddress,
        pub num_of_classes: u256,
        pub name_of_org: ByteArray,
        pub organization_address: ContractAddress,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Class {
        pub address_of_org: ContractAddress,
        pub instructor: ContractAddress,
        pub num_of_reg_students: u32,
        pub active_status: bool,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Bootcampclass {
        pub address_of_org: ContractAddress,
        pub bootcamp_id: u64,
        pub attendance: bool,
        pub student_address: ContractAddress,
        pub class_id: u64,
    }


    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct RegisteredBootcamp {
        pub address_of_org: ContractAddress,
        pub student: ContractAddress,
        pub acceptance_status: bool,
        pub bootcamp_id: u64,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Student {
        pub address_of_student: ContractAddress,
        pub num_of_bootcamps_registered_for: u256,
        pub status: u8,
        pub student_details_uri: ByteArray,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Sponsor: Sponsor,
        Withdrawn: Withdrawn,
        OrganizationProfile: OrganizationProfile,
        InstructorAddedToOrg: InstructorAddedToOrg,
        InstructorRemovedFromOrg: InstructorRemovedFromOrg,
        BootCampCreated: BootCampCreated,
        ActiveMeetLinkAdded: ActiveMeetLinkAdded,
        VideoLinkUploaded: VideoLinkUploaded,
        BootcampRegistration: BootcampRegistration,
        RegistrationApproved: RegistrationApproved,
        RegistrationDeclined: RegistrationDeclined,
        AttendanceMarked: AttendanceMarked,
        StudentsCertified: StudentsCertified,
        SponsorshipAddressSet: SponsorshipAddressSet,
        OrganizationSponsored: OrganizationSponsored,
        SponsorshipFundWithdrawn: SponsorshipFundWithdrawn,
        OrganizationSuspended: OrganizationSuspended,
        BootCampSuspended: BootCampSuspended,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Sponsor {
        pub amt: u256,
        pub uri: ByteArray,
        #[key]
        pub organization: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        pub amt: u256,
        #[key]
        pub organization: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationProfile {
        pub org_name: ByteArray,
        pub org_ipfs_uri: ByteArray,
        //     #[key]
    //     pub organization: ContractAddress
    // }
    }

    #[derive(Drop, starknet::Event)]
    pub struct InstructorAddedToOrg {
        pub org_name: ByteArray,
        #[key]
        pub instructor: Array<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct InstructorRemovedFromOrg {
        pub instructor_addr: ContractAddress,
        pub org_owner: ContractAddress,
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
    pub struct ActiveMeetLinkAdded {
        pub meet_link: ByteArray,
        pub bootcamp_id: u64,
        pub is_instructor: bool,
        pub org_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VideoLinkUploaded {
        pub video_link: ByteArray,
        pub is_instructor: bool,
        pub org_address: ContractAddress,
        pub bootcamp_id: u64,
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
    pub struct AttendanceMarked {
        pub org_address: ContractAddress,
        pub instructor_address: ContractAddress,
        pub class_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StudentsCertified {
        pub org_address: ContractAddress,
        pub class_id: u64,
        pub student_addresses: Array<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipAddressSet {
        pub sponsor_contract_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationSponsored {
        pub organization_address: ContractAddress,
        pub sponsor_uri: ByteArray,
        pub sponsorship_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SponsorshipFundWithdrawn {
        pub withdrawal_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationSuspended {
        pub org_contract_address: ContractAddress,
        pub org_name: ByteArray,
        pub suspended: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BootCampSuspended {
        pub org_contract_address: ContractAddress,
        pub bootcamp_id: u64,
        pub bootcamp_name: ByteArray,
        pub suspended: bool,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        class_hash: ClassHash,
        _token_address: ContractAddress,
        sponsorship_contract_address: ContractAddress,
    ) {
        self.hash.write(class_hash);
        self.token_address.write(_token_address);
        self.sponsorship_contract_address.write(sponsorship_contract_address);
        self.admin.write(admin);
    }

    #[abi(embed_v0)]
    impl IAttenSysOrgImpl of super::IAttenSysOrg<ContractState> {
        //ability to create organization profile, each org info should be saved properly, use
        //mappings and structs where necessary
        fn create_org_profile(
            ref self: ContractState, org_name: ByteArray, org_ipfs_uri: ByteArray,
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
                    org_ipfs_uri: org_ipfs_uri.clone(),
                    total_sponsorship_fund: 0,
                };

                let uri = org_ipfs_uri.clone();

                self.all_org_info.append().write(org_call_data);
                self
                    .organization_info
                    .entry(creator)
                    .write(
                        Organization {
                            address_of_org: creator,
                            org_name: org_name.clone(),
                            number_of_instructors: 0,
                            number_of_students: 0,
                            number_of_all_classes: 0,
                            number_of_all_bootcamps: 0,
                            org_ipfs_uri: org_ipfs_uri,
                            total_sponsorship_fund: 0,
                        },
                    );
                let orginization_name = org_name.clone();

                self.emit(OrganizationProfile { org_name: orginization_name, org_ipfs_uri: uri });
                // add the organization creator as an instructor
                add_instructor_to_org(ref self, creator, creator, org_name);
            } else {
                panic!("created an organization.");
            }
        }

        // add array of instructor to an organization
        fn add_instructor_to_org(
            ref self: ContractState, instructor: Array<ContractAddress>, org_name: ByteArray,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                //assert organization not suspended
                assert(!self.org_suspended.entry(caller).read(), 'organization suspended');
                for i in 0
                    ..instructor
                        .len() {
                            add_instructor_to_org(
                                ref self, caller, *instructor[i], org_name.clone()
                            );
                        };
                self
                    .emit(
                        InstructorAddedToOrg { org_name: org_name.clone(), instructor: instructor },
                    )
            } else {
                panic!("no organization created.");
            }
        }

        //    remove instructor from an organization.
        fn remove_instructor_from_org(ref self: ContractState, instructor: ContractAddress) {
            assert(!instructor.is_zero(), 'zero address.');
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated an organization
            if status {
                //assert organization not suspended
                assert(!self.org_suspended.entry(caller).read(), 'organization suspended');

                if self.instructor_part_of_org.entry((caller, instructor)).read() {
                    self.instructor_part_of_org.entry((caller, instructor)).write(false);

                    let mut org_call_data: Organization = self
                        .organization_info
                        .entry(caller)
                        .read();
                    org_call_data.number_of_instructors -= 1;
                    self.organization_info.entry(caller).write(org_call_data);
                    let instructors_in_org = self.org_to_instructors.entry(caller);

                    // let mut addresses : Vec<Instructor> = array![];
                    for i in 0
                        ..instructors_in_org
                            .len() {
                                let derived_instructor = self
                                    .org_to_instructors
                                    .entry(caller)
                                    .at(i)
                                    .read()
                                    .address_of_instructor;

                                if instructor == derived_instructor {
                                    // replace the last guy in the spot of the removed instructor
                                    let lastInstructor = self
                                        .org_to_instructors
                                        .entry(caller)
                                        .at(instructors_in_org.len() - 1)
                                        .read();
                                    self
                                        .org_to_instructors
                                        .entry(caller)
                                        .at(i)
                                        .write(lastInstructor);
                                }

                                // Event ng for removing an inspector
                                self
                                    .emit(
                                        InstructorRemovedFromOrg {
                                            instructor_addr: instructor, org_owner: caller,
                                        },
                                    )
                            }
                } else {
                    panic!("not an instructor.");
                }
            } else {
                panic!("no organization created.");
            }
        }

        //Add function to allow saving URI's from recorded video #33
        // Add function to allow organization to save the uri obtained from uploading recorded video
        // to ipfs in contract
        fn add_uploaded_video_link(
            ref self: ContractState,
            video_link: ByteArray,
            is_instructor: bool,
            org_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            assert(video_link != "", 'empty link');
            let video_link_cp = video_link.clone();
            let mut status: bool = false;
            let caller = get_caller_address();
            let is_instructor_cp = is_instructor.clone();
            if is_instructor {
                status = self.instructor_part_of_org.entry((org_address, caller)).read();
            } else {
                assert(org_address == caller, 'caller not org address');
                status = self.created_status.entry(caller).read();
            }

            // confirm that the caller is associated an organization
            if (status) {
                assert(
                    !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
                if is_instructor {
                    self
                        .org_to_uploaded_videos_link
                        .entry((org_address, bootcamp_id))
                        .append()
                        .write(video_link);
                } else {
                    self
                        .org_to_uploaded_videos_link
                        .entry((caller, bootcamp_id))
                        .append()
                        .write(video_link);
                }

                self
                    .emit(
                        VideoLinkUploaded {
                            video_link: video_link_cp,
                            is_instructor: is_instructor_cp,
                            org_address: org_address,
                            bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("not part of organization.");
            };
        }

        // Must make the admin an instructor to successfully call this
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
            let status: bool = self.created_status.entry(caller).read();
            // confirm that the caller is associated to an organization
            if (status) {
                //assert organization not suspended
                assert(!self.org_suspended.entry(caller).read(), 'organization suspended');
                // constructor arguments
                let mut constructor_args = array![];
                nft_uri.serialize(ref constructor_args);
                nft_name.serialize(ref constructor_args);
                nft_symbol.serialize(ref constructor_args);
                //deploy contract
                let contract_address_salt: felt252 = caller.into();
                let (deployed_contract_address, _) = deploy_syscall(
                    self.hash.read(), contract_address_salt, constructor_args.span(), false,
                )
                    .expect('failed to deploy_syscall');
                let index: u64 = self.org_to_bootcamps.entry(caller).len().into();
                // create bootcamp and update
                let bootcamp_call_data: Bootcamp = Bootcamp {
                    bootcamp_id: index,
                    address_of_org: caller,
                    org_name: org_name.clone(),
                    bootcamp_name: bootcamp_name.clone(),
                    number_of_instructors: 0,
                    number_of_students: 0,
                    number_of_all_bootcamp_classes: 0,
                    nft_address: deployed_contract_address,
                    bootcamp_ipfs_uri: bootcamp_ipfs_uri.clone(),
                    active_meet_link: "",
                };

                //append into the array of bootcamps associated to an organization
                self.org_to_bootcamps.entry(caller).append().write(bootcamp_call_data);
                self
                    .all_bootcamps_created
                    .append()
                    .write(
                        Bootcamp {
                            bootcamp_id: index,
                            address_of_org: caller,
                            org_name: org_name.clone(),
                            bootcamp_name: bootcamp_name.clone(),
                            number_of_instructors: 0,
                            number_of_students: 0,
                            number_of_all_bootcamp_classes: 0,
                            nft_address: deployed_contract_address,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri.clone(),
                            active_meet_link: "",
                        },
                    );

                // update the number of bootcamps created in an organization
                let mut org_call_data: Organization = self.organization_info.entry(caller).read();
                org_call_data.number_of_all_bootcamps += 1;
                self.organization_info.entry(caller).write(org_call_data);

                // Emmiting a Bootcamp Event
                self
                    .emit(
                        BootCampCreated {
                            org_name: org_name,
                            bootcamp_name: bootcamp_name,
                            nft_name: nft_name,
                            nft_symbol: nft_symbol,
                            nft_uri: nft_uri,
                            num_of_classes: num_of_class_to_create,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri,
                        },
                    );
                //create classes
                create_a_class(ref self, caller, num_of_class_to_create, index);
            } else {
                panic!("no organization created.");
            }
        }

        fn add_active_meet_link(
            ref self: ContractState,
            meet_link: ByteArray,
            bootcamp_id: u64,
            is_instructor: bool,
            org_address: ContractAddress,
        ) {
            let mut status: bool = false;
            let caller = get_caller_address();
            let active_link = meet_link.clone();
            let is_instructor_cp = is_instructor.clone();
            if is_instructor {
                status = self.instructor_part_of_org.entry((org_address, caller)).read();
            } else {
                assert(org_address == caller, 'caller not org address');
                status = self.created_status.entry(caller).read();
            }

            // confirm that the caller is associated an organization
            if (status) {
                assert(
                    !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
                if is_instructor {
                    let mut bootcamp: Bootcamp = self
                        .org_to_bootcamps
                        .entry(org_address)
                        .at(bootcamp_id)
                        .read();
                    bootcamp.active_meet_link = meet_link;
                    self.org_to_bootcamps.entry(org_address).at(bootcamp_id).write(bootcamp);
                } else {
                    let mut bootcamp: Bootcamp = self
                        .org_to_bootcamps
                        .entry(caller)
                        .at(bootcamp_id)
                        .read();

                    bootcamp.active_meet_link = meet_link;
                    self.org_to_bootcamps.entry(caller).at(bootcamp_id).write(bootcamp);
                }
                // pub meet_link: ByteArray,
                // pub bootcamp_id: u64,
                // pub is_instructor: bool,
                // pub org_address: ContractAddress,

                // Emitting events when a active link is added

                self
                    .emit(
                        ActiveMeetLinkAdded {
                            meet_link: active_link,
                            bootcamp_id: bootcamp_id.clone(),
                            is_instructor: is_instructor_cp,
                            org_address: org_address,
                        },
                    );
            } else {
                panic!("not part of organization.");
            };
        }

        fn register_for_bootcamp(
            ref self: ContractState,
            org_: ContractAddress,
            bootcamp_id: u64,
            student_uri: ByteArray,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(org_).read();
            // check org is created
            if status {
                assert(
                    !self.bootcamp_suspended.entry(org_).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
                let mut bootcamp = self.org_to_bootcamps.entry(org_);
                for i in 0
                    ..bootcamp
                        .len() {
                            if i == bootcamp_id {
                                let mut student: Student = self.student_info.entry(caller).read();
                                student
                                    .num_of_bootcamps_registered_for = student
                                    .num_of_bootcamps_registered_for
                                    + 1;
                                student.student_details_uri = student_uri.clone();
                                self.student_info.entry(caller).write(student);
                                self
                                    .org_to_requests
                                    .entry(org_)
                                    .append()
                                    .write(
                                        Student {
                                            address_of_student: caller,
                                            num_of_bootcamps_registered_for: self
                                                .student_info
                                                .entry(caller)
                                                .read()
                                                .num_of_bootcamps_registered_for,
                                            status: 0,
                                            student_details_uri: self
                                                .student_info
                                                .entry(caller)
                                                .read()
                                                .student_details_uri,
                                        },
                                    );
                            }
                        };

                self.emit(BootcampRegistration { org_address: org_, bootcamp_id: bootcamp_id });
            } else {
                panic!("not part of organization.");
            }
        }

        fn approve_registration(
            ref self: ContractState, student_address: ContractAddress, bootcamp_id: u64,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            if status {
                for i in 0
                    ..self
                        .org_to_requests
                        .entry(caller)
                        .len() {
                            if self
                                .org_to_requests
                                .entry(caller)
                                .at(i)
                                .read()
                                .address_of_student == student_address {
                                let mut student = self.org_to_requests.entry(caller).at(i).read();
                                student.status = 1;
                                self.org_to_requests.entry(caller).at(i).write(student);

                                let mut the_bootcamp: Bootcamp = self
                                    .org_to_bootcamps
                                    .entry(caller)
                                    .at(bootcamp_id)
                                    .read();

                                the_bootcamp.number_of_students = the_bootcamp.number_of_students
                                    + 1;
                                self
                                    .org_to_bootcamps
                                    .entry(caller)
                                    .at(bootcamp_id)
                                    .write(the_bootcamp);
                                self
                                    .student_address_to_specific_bootcamp
                                    .entry((caller, student_address))
                                    .append()
                                    .write(
                                        RegisteredBootcamp {
                                            address_of_org: caller,
                                            student: student_address.clone(),
                                            acceptance_status: true,
                                            bootcamp_id: bootcamp_id,
                                        },
                                    );
                                self
                                    .student_address_to_bootcamps
                                    .entry(student_address)
                                    .append()
                                    .write(
                                        RegisteredBootcamp {
                                            address_of_org: caller,
                                            student: student_address,
                                            acceptance_status: true,
                                            bootcamp_id: bootcamp_id,
                                        },
                                    );
                            }
                            // update organization and instructor data
                            let mut org = self.organization_info.entry(caller).read();
                            org.number_of_students = org.number_of_students + 1;
                            self.organization_info.entry(caller).write(org);
                        };

                self
                    .emit(
                        RegistrationApproved {
                            student_address: student_address, bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("no organization created.");
            }
        }

        fn decline_registration(
            ref self: ContractState, student_address: ContractAddress, bootcamp_id: u64,
        ) {
            let caller = get_caller_address();
            let status: bool = self.created_status.entry(caller).read();
            if status {
                for i in 0
                    ..self
                        .org_to_requests
                        .entry(caller)
                        .len() {
                            if self
                                .org_to_requests
                                .entry(caller)
                                .at(i)
                                .read()
                                .address_of_student == student_address {
                                let mut student = self.org_to_requests.entry(caller).at(i).read();
                                student.status = 2;
                                self.org_to_requests.entry(caller).at(i).write(student);
                            }
                        };

                self
                    .emit(
                        RegistrationDeclined {
                            student_address: student_address, bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("no organization created.");
            }
        }

        fn get_all_registration_request(
            self: @ContractState, org_: ContractAddress,
        ) -> Array<Student> {
            get_all_registration_request(self, org_)
        }

        fn mark_attendance_for_a_class(
            ref self: ContractState,
            org_: ContractAddress,
            instructor_: ContractAddress,
            class_id: u64,
            bootcamp_id: u64,
        ) {
            let caller = get_caller_address();
            let class_id_len = self.bootcamp_class_data_id.entry((org_, bootcamp_id)).len();
            assert(class_id < class_id_len && class_id >= 0, 'invalid class id');
            let mut instructor_class = self
                .org_instructor_classes
                .entry((org_, instructor_))
                .at(class_id)
                .read();
            let reg_status = self
                .student_attendance_status
                .entry((caller, bootcamp_id, class_id, caller))
                .read();
            assert(instructor_class.active_status, 'not a class');
            assert(!reg_status, 'attendance marked');
            self.student_attendance_status.entry((org_, bootcamp_id, class_id, caller)).write(true);
            self
                .emit(
                    AttendanceMarked {
                        org_address: org_, instructor_address: instructor_, class_id: class_id,
                    },
                );
        }

        fn batch_certify_students(
            ref self: ContractState, org_: ContractAddress, bootcamp_id: u64,
        ) {
            //only instructor under an organization issues certificate
            //all of the registered students with attendance
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            let mut attendance_counter = 0;
            assert(is_instructor, 'not an instructor');

            let mut arr_of_request = array![];
            for i in 0
                ..self
                    .org_to_requests
                    .entry(org_)
                    .len() {
                        if self.org_to_requests.entry(org_).at(i).status.read() == 1 {
                            arr_of_request
                                .append(
                                    self.org_to_requests.entry(org_).at(i).address_of_student.read()
                                );
                        }
                    };
            let mut class_id_arr = array![];
            for i in 0
                ..self
                    .bootcamp_class_data_id
                    .entry((org_, bootcamp_id))
                    .len() {
                        class_id_arr
                            .append(
                                self.bootcamp_class_data_id.entry((org_, bootcamp_id)).at(i).read()
                            );
                    };
            //@todo mint an nft associated to the bootcamp to each student.
            for i in 0
                ..arr_of_request
                    .len() {
                        for k in 0
                            ..class_id_arr
                                .len() {
                                    let reg_status = self
                                        .student_attendance_status
                                        .entry(
                                            (
                                                org_,
                                                bootcamp_id,
                                                *class_id_arr.at(k),
                                                *arr_of_request.at(i)
                                            )
                                        )
                                        .read();
                                    if reg_status {
                                        attendance_counter += 1;
                                    }
                                };
                        let attendance_criteria = class_id_arr.len() * (1 / 2);
                        if attendance_counter > attendance_criteria {
                            self
                                .certify_student
                                .entry((org_, bootcamp_id, *arr_of_request.at(i)))
                                .write(true);
                            self
                                .certified_students_for_bootcamp
                                .entry((org_, bootcamp_id))
                                .append()
                                .write(*arr_of_request.at(i));
                            attendance_counter = 0;
                        };
                    };
            self
                .emit(
                    StudentsCertified {
                        org_address: org_, class_id: bootcamp_id, student_addresses: arr_of_request,
                    },
                )
        }
        fn single_certify_student(
            ref self: ContractState,
            org_: ContractAddress,
            bootcamp_id: u64,
            students: ContractAddress
        ) {
            let caller = get_caller_address();
            let is_instructor = self.instructor_part_of_org.entry((org_, caller)).read();
            assert(is_instructor, 'not an instructor');
            //@todo check if student has been certified
            //@todo check if address is a registered student
            self.certify_student.entry((org_, bootcamp_id, students)).write(true);
            self
                .certified_students_for_bootcamp
                .entry((org_, bootcamp_id))
                .append()
                .write(students);
        }

        fn setSponsorShipAddress(
            ref self: ContractState, sponsor_contract_address: ContractAddress,
        ) {
            only_admin(ref self);
            assert(!sponsor_contract_address.is_zero(), 'Null address not allowed');
            self.sponsorship_contract_address.write(sponsor_contract_address);
            self.emit(SponsorshipAddressSet { sponsor_contract_address });
        }

        fn sponsor_organization(
            ref self: ContractState, organization: ContractAddress, uri: ByteArray, amt: u256,
        ) {
            assert(!organization.is_zero(), 'not an instructor');
            assert(uri.len() > 0, 'uri is empty');

            let sender = get_caller_address();
            let status: bool = self.created_status.entry(organization).read();
            if (status) {
                //assert organization not suspended
                assert(!self.org_suspended.entry(organization).read(), 'organization suspended');
                let balanceBefore = self.org_to_balance_of_sponsorship.entry(organization).read();
                self.org_to_balance_of_sponsorship.entry(organization).write(balanceBefore + amt);
                let sponsor_contract_address = self.sponsorship_contract_address.read();
                let token_contract_address = self.token_address.read();
                let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                    contract_address: sponsor_contract_address,
                };
                sponsor_dispatcher.deposit(sender, token_contract_address, amt);
                self.emit(Sponsor { amt, uri, organization });
            } else {
                panic!("not an organization");
            }
        }

        fn withdraw_sponsorship_fund(ref self: ContractState, amt: u256) {
            let organization = get_caller_address();
            assert(amt > 0, 'Invalid withdrawal amount');
            let status: bool = self.created_status.entry(organization).read();
            if (status) {
                assert(
                    self.org_to_balance_of_sponsorship.entry(organization).read() >= amt,
                    'insufficient funds',
                );
                let contract_address = self.token_address.read();
                let sponsor_contract_address = self.sponsorship_contract_address.read();
                let sponsor_dispatcher = IAttenSysSponsorDispatcher {
                    contract_address: sponsor_contract_address,
                };
                sponsor_dispatcher.withdraw(contract_address, amt);

                let balanceBefore = self.org_to_balance_of_sponsorship.entry(organization).read();
                self.org_to_balance_of_sponsorship.entry(organization).write(balanceBefore - amt);
                // let contract_address = self.token_address.read();
                // let sponsor_dispatcher = IAttenSysSponsorDispatcher { contract_address };
                /// @maintainer What's the need for this deposit func, I'm guessing it's an error
                // sponsor_dispatcher.deposit(organization, self.token_address.read(), amt);
                self.emit(Withdrawn { amt, organization });
            } else {
                panic!("not an organization");
            }
        }

        fn suspend_organization(ref self: ContractState, org_: ContractAddress, suspend: bool) {
            only_admin(ref self);
            let org: Organization = self.organization_info.entry(org_).read();
            assert(!org.address_of_org.is_zero(), 'Organization not created');
            if suspend {
                assert(!self.org_suspended.entry(org_).read(), 'Organization suspended');
                self.org_suspended.entry(org_).write(true);
            } else {
                assert(self.org_suspended.entry(org_).read(), 'Organization not suspended');
                self.org_suspended.entry(org_).write(false);
            }
            self
                .emit(
                    OrganizationSuspended {
                        org_contract_address: org_, org_name: org.org_name, suspended: suspend,
                    },
                );
        }

        fn suspend_org_bootcamp(
            ref self: ContractState, org_: ContractAddress, bootcamp_id_: u64, suspend: bool,
        ) {
            only_admin(ref self);
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id_).read();
            assert(!bootcamp.address_of_org.is_zero(), 'Invalid BootCamp');
            if suspend {
                assert(
                    !self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).read(),
                    'BootCamp suspended',
                );
                self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).write(true);
            } else {
                assert(
                    self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).read(),
                    'BootCamp not suspended',
                );
                self.bootcamp_suspended.entry(org_).entry(bootcamp_id_).write(false);
            }
            self
                .emit(
                    BootCampSuspended {
                        org_contract_address: org_,
                        bootcamp_id: bootcamp_id_,
                        bootcamp_name: bootcamp.bootcamp_name,
                        suspended: suspend,
                    },
                );
        }
        // read functions
        fn get_all_org_bootcamps(self: @ContractState, org_: ContractAddress) -> Array<Bootcamp> {
            let mut arr_of_all_created_bootcamps = array![];

            for i in 0
                ..self
                    .org_to_bootcamps
                    .entry(org_)
                    .len() {
                        arr_of_all_created_bootcamps
                            .append(self.org_to_bootcamps.entry(org_).at(i).read());
                    };

            arr_of_all_created_bootcamps
        }

        fn get_bootcamp_active_meet_link(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
        ) -> ByteArray {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp.active_meet_link
        }

        fn get_bootcamp_uploaded_video_link(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
        ) -> Array<ByteArray> {
            let mut arr_of_all_uploaded_bootcamps_link = array![];

            for i in 0
                ..self
                    .org_to_uploaded_videos_link
                    .entry((org_, bootcamp_id))
                    .len() {
                        arr_of_all_uploaded_bootcamps_link
                            .append(
                                self
                                    .org_to_uploaded_videos_link
                                    .entry((org_, bootcamp_id))
                                    .at(i)
                                    .read(),
                            );
                    };
            arr_of_all_uploaded_bootcamps_link
        }

        // read functions
        fn get_all_bootcamps_on_platform(self: @ContractState) -> Array<Bootcamp> {
            let mut arr_of_all_created_bootcamps_on_platform = array![];

            for i in 0
                ..self
                    .all_bootcamps_created
                    .len() {
                        arr_of_all_created_bootcamps_on_platform
                            .append(self.all_bootcamps_created.at(i).read());
                    };

            arr_of_all_created_bootcamps_on_platform
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
                                                .read(),
                                        );

                                    for k in 0
                                        ..self
                                            .org_instructor_classes
                                            .entry(
                                                (
                                                    *arr_of_org.at(i_u32).address_of_org,
                                                    *arr_of_instructors
                                                        .at(j_u32)
                                                        .address_of_instructor,
                                                ),
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
                                                                        .address_of_instructor,
                                                                ),
                                                            )
                                                            .at(k)
                                                            .read(),
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
            self: @ContractState, org_: ContractAddress, instructor: ContractAddress,
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

        fn get_instructor_info(
            self: @ContractState, instructor: ContractAddress,
        ) -> Array<Instructor> {
            let mut arr = array![];
            for i in 0
                ..self
                    .instructor_key_to_info
                    .entry(instructor)
                    .len() {
                        arr.append(self.instructor_key_to_info.entry(instructor).at(i).read());
                    };
            arr
        }
        fn get_bootcamp_info(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
        ) -> Bootcamp {
            let bootcamp: Bootcamp = self.org_to_bootcamps.entry(org_).at(bootcamp_id).read();
            bootcamp
        }


        fn get_org_sponsorship_balance(
            self: @ContractState, organization: ContractAddress,
        ) -> u256 {
            self.org_to_balance_of_sponsorship.entry(organization).read()
        }
        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin != self.zero_address(), 'zero address not allowed');
            assert(get_caller_address() == self.admin.read(), 'unauthorized caller');

            self.intended_new_admin.write(new_admin);
        }

        fn claim_admin_ownership(ref self: ContractState) {
            assert(get_caller_address() == self.intended_new_admin.read(), 'unauthorized caller');

            self.admin.write(self.intended_new_admin.read());
            self.intended_new_admin.write(self.zero_address());
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn get_new_admin(self: @ContractState) -> ContractAddress {
            self.intended_new_admin.read()
        }

        fn is_org_suspended(self: @ContractState, org_: ContractAddress) -> bool {
            let is_suspended: bool = self.org_suspended.entry(org_).read();
            is_suspended
        }

        fn is_bootcamp_suspended(
            self: @ContractState, org_: ContractAddress, bootcamp_id: u64,
        ) -> bool {
            let is_suspended: bool = self.bootcamp_suspended.entry(org_).entry(bootcamp_id).read();
            is_suspended
        }

        fn get_registered_bootcamp(
            self: @ContractState, student: ContractAddress
        ) -> Array<RegisteredBootcamp> {
            let mut array_of_reg_bootcamp = array![];
            for i in 0
                ..self
                    .student_address_to_bootcamps
                    .entry(student)
                    .len() {
                        array_of_reg_bootcamp
                            .append(self.student_address_to_bootcamps.entry(student).at(i).read());
                    };
            array_of_reg_bootcamp
        }
        fn get_specific_organization_registered_bootcamp(
            self: @ContractState, org: ContractAddress, student: ContractAddress
        ) -> Array<RegisteredBootcamp> {
            let mut array_of_specific_org_reg_bootcamp = array![];
            for i in 0
                ..self
                    .student_address_to_specific_bootcamp
                    .entry((org, student))
                    .len() {
                        array_of_specific_org_reg_bootcamp
                            .append(
                                self
                                    .student_address_to_specific_bootcamp
                                    .entry((org, student))
                                    .at(i)
                                    .read()
                            );
                    };
            array_of_specific_org_reg_bootcamp
        }
        fn get_class_attendance_status(
            self: @ContractState,
            org: ContractAddress,
            bootcamp_id: u64,
            class_id: u64,
            student: ContractAddress
        ) -> bool {
            let mut instructor_class = self
                .org_instructor_classes
                .entry((org, org))
                .at(class_id)
                .read();
            assert(instructor_class.active_status, 'not a class');
            let class_id_len = self.bootcamp_class_data_id.entry((org, bootcamp_id)).len();
            assert(class_id < class_id_len && class_id >= 0, 'invalid class id');

            let reg_status = self
                .student_attendance_status
                .entry((org, bootcamp_id, class_id, student))
                .read();
            reg_status
        }

        fn get_all_bootcamp_classes(
            self: @ContractState, org: ContractAddress, bootcamp_id: u64
        ) -> Array<u64> {
            let mut arr = array![];
            for i in 0
                ..self
                    .bootcamp_class_data_id
                    .entry((org, bootcamp_id))
                    .len() {
                        arr
                            .append(
                                self.bootcamp_class_data_id.entry((org, bootcamp_id)).at(i).read()
                            );
                    };
            arr
        }
        fn get_certified_student_bootcamp_address(
            self: @ContractState, org: ContractAddress, bootcamp_id: u64
        ) -> Array<ContractAddress> {
            let mut arr = array![];
            for i in 0
                ..self
                    .certified_students_for_bootcamp
                    .entry((org, bootcamp_id))
                    .len() {
                        arr
                            .append(
                                self
                                    .certified_students_for_bootcamp
                                    .entry((org, bootcamp_id))
                                    .at(i)
                                    .read()
                            );
                    };
            arr
        }
        fn get_bootcamp_certification_status(
            self: @ContractState, org: ContractAddress, bootcamp_id: u64, student: ContractAddress
        ) -> bool {
            self.certify_student.entry((org, bootcamp_id, student)).read()
        }
    }

    fn create_a_class(
        ref self: ContractState,
        org_: ContractAddress,
        num_of_class_to_create: u256,
        bootcamp_id: u64,
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
                bootcamp_id: bootcamp_id,
            };
            // update the org_instructor to classes created
            self.org_instructor_classes.entry((org_, caller)).append().write(class_data);
            // update all general classes linked to org
            let mut org: Organization = self.organization_info.entry(org_).read();
            org.number_of_all_classes += num_of_class_to_create;
            self.organization_info.entry(org_).write(org);

            for i in 0
                ..num_of_class_to_create {
                    self
                        .bootcamp_class_data_id
                        .entry((org_, bootcamp_id))
                        .append()
                        .write(i.try_into().unwrap())
                }
        } else {
            panic!("not an instructor in this org");
        }
    }

    // add instructor to an organization
    fn add_instructor_to_org(
        ref self: ContractState,
        caller: ContractAddress,
        instructor: ContractAddress,
        org_name: ByteArray,
    ) {
        assert(!instructor.is_zero(), 'zero address.');
        if !self.instructor_part_of_org.entry((caller, instructor)).read() {
            self.instructor_part_of_org.entry((caller, instructor)).write(true);

            let mut instructor_data: Instructor = Instructor {
                address_of_instructor: instructor,
                num_of_classes: 0,
                name_of_org: org_name.clone(),
                organization_address: caller,
            };
            self.org_to_instructors.entry(caller).append().write(instructor_data);
            self
                .instructor_key_to_info
                .entry(instructor)
                .append()
                .write(
                    Instructor {
                        address_of_instructor: instructor,
                        num_of_classes: 0,
                        name_of_org: org_name,
                        organization_address: caller,
                    },
                );
            let mut org_call_data: Organization = self.organization_info.entry(caller).read();
            org_call_data.number_of_instructors += 1;
            self.organization_info.entry(caller).write(org_call_data);
        } else {
            panic!("already added.");
        }
    }


    fn get_all_registration_request(self: @ContractState, org_: ContractAddress) -> Array<Student> {
        let mut arr_of_request = array![];

        for i in 0
            ..self
                .org_to_requests
                .entry(org_)
                .len() {
                    arr_of_request.append(self.org_to_requests.entry(org_).at(i).read());
                };

        arr_of_request
    }

    fn only_admin(ref self: ContractState) {
        let _caller = get_caller_address();
        assert(_caller == self.admin.read(), 'Not admin');
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn zero_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }
    }
}
