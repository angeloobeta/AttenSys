use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysCourse<TContractState> {
    fn create_course(ref self: TContractState, owner_: ContractAddress, accessment_: bool, nft_name : ByteArray, nft_symbol: ByteArray, nft_uri: ByteArray)-> ContractAddress;
    fn add_replace_course_content(
        ref self: TContractState,
        course_identifier: u256,
        owner_: ContractAddress,
        new_course_uri_a: felt252,
        new_course_uri_b: felt252
    );
    //untested
    fn finish_course_claim_certification(ref self: TContractState, course_identifier: u256);
    //untested
    fn check_course_completion_status_n_certification(
        self: @TContractState, course_identifier: u256, candidate: ContractAddress
    ) -> bool;
    fn get_course_infos(
        self: @TContractState, course_identifiers: Array<u256>
    ) -> Array<AttenSysCourse::Course>;
    //untested
    fn get_user_completed_courses(self: @TContractState, user: ContractAddress) -> Array<u256>;
    fn get_all_courses_info(self: @TContractState) -> Array<AttenSysCourse::Course>;
    fn get_all_creator_courses(
        self: @TContractState, owner_: ContractAddress
    ) -> Array<AttenSysCourse::Course>;
    fn get_creator_info(self: @TContractState, creator: ContractAddress) -> AttenSysCourse::Creator;
}

//Todo, make a count of the total number of users that finished the course.

#[starknet::interface]
pub trait IAttenSysNft<TContractState> {
    // NFT contract
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

#[starknet::contract]
mod AttenSysCourse {
    use super::IAttenSysNftDispatcherTrait;
use core::starknet::{ContractAddress, get_caller_address, syscalls::deploy_syscall, ClassHash};
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
        MutableVecTrait
    };

    #[storage]
    struct Storage {
        //save content creator info including all all contents created.
        course_creator_info: Map::<ContractAddress, Creator>,
        //saves specific course (course details only), set this when creating course
        specific_course_info_with_identifer: Map::<u256, Course>,
        //saves all course info
        all_course_info: Vec<Course>,
        //saves a course completion status after successfully completed a particular course
        completion_status: Map::<(ContractAddress, u256), bool>,
        //saves completed courses by user
        completed_courses: Map::<ContractAddress, Vec<u256>>,
        //saves identifier tracker
        identifier_tracker: u256,
        //maps, creator's address to an array of struct of all courses created.
        creator_to_all_content: Map::<ContractAddress, Vec<Course>>,
        //nft classhash
          hash: ClassHash,
        //admin address
          admin : ContractAddress,
        //saves nft contract address associated to event
         course_nft_contract_address : Map::<u256, ContractAddress>,
        //tracks all minted nft id minted by events
         track_minted_nft_id : Map::<(u256, ContractAddress), u256>,
    }
    //find a way to keep track of all course identifiers for each owner.
    #[derive(Drop, Serde, starknet::Store)]
    pub struct Creator {
        pub address: ContractAddress,
        pub number_of_courses: u256,
        pub creator_status: bool,
    }

    //consider the idea of having the uri for each course within the course struct.

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Course {
        pub owner: ContractAddress,
        pub course_identifier: u256,
        pub accessment: bool,
        pub uri: Uri,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Uri {
        pub first: felt252,
        pub second: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, _hash: ClassHash) {
        self.admin.write(owner);
        self.hash.write(_hash);
    }
    
    #[abi(embed_v0)]
    impl IAttenSysCourseImpl of super::IAttenSysCourse<ContractState> {
        fn create_course(ref self: ContractState, owner_: ContractAddress, accessment_: bool, nft_name : ByteArray, nft_symbol: ByteArray, nft_uri: ByteArray) -> ContractAddress {
            //make an address zero check
            let identifier_count = self.identifier_tracker.read();
            let current_identifier = identifier_count + 1;
            let mut current_creator_info: Creator = self.course_creator_info.entry(owner_).read();
            if current_creator_info.number_of_courses > 0 {
                assert(owner_ == get_caller_address(), 'not owner');
                current_creator_info.number_of_courses += 1;
            } else {
                current_creator_info.address = owner_;
                current_creator_info.number_of_courses += 1;
                current_creator_info.creator_status = true;
            }
            let empty_uri = Uri { first: '', second: '', };
            let mut course_call_data: Course = Course {
                owner: owner_,
                course_identifier: current_identifier,
                accessment: accessment_,
                uri: empty_uri,
            };

            self.creator_to_all_content.entry(owner_).append().write(course_call_data);
            self.course_creator_info.entry(owner_).write(current_creator_info);
            self
                .specific_course_info_with_identifer
                .entry(current_identifier)
                .write(course_call_data);
            self.identifier_tracker.write(current_identifier);
                          // constructor arguments   
                          let mut constructor_args = array![];
                          nft_uri.serialize(ref constructor_args);
                          nft_name.serialize(ref constructor_args);
                          nft_symbol.serialize(ref constructor_args);   
                          //deploy contract
                let (deployed_contract_address, _) = deploy_syscall(self.hash.read(), 0, constructor_args.span(), false).expect('failed to deploy_syscall');
            self.track_minted_nft_id.entry((current_identifier,deployed_contract_address)).write(1);
            self.course_nft_contract_address.entry(current_identifier).write(deployed_contract_address);
                
                deployed_contract_address
        }


        //from frontend, the idea will be to obtain the previous uri, transfer content from the
        //previous uri to the new uri
        // and write the new uri to state.
        fn add_replace_course_content(
            ref self: ContractState,
            course_identifier: u256,
            owner_: ContractAddress,
            new_course_uri_a: felt252,
            new_course_uri_b: felt252
        ) {
            let mut current_course_info: Course = self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .read();
            let pre_existing_counter = self.identifier_tracker.read();
            assert(course_identifier <= pre_existing_counter, 'course non-existent');
            assert(current_course_info.owner == get_caller_address(), 'not owner');
            let call_data: Uri = Uri { first: new_course_uri_a, second: new_course_uri_b, };
            current_course_info.uri = call_data;
            self
                .specific_course_info_with_identifer
                .entry(course_identifier)
                .write(current_course_info);

            //run a loop to check if course ID exists in all course info vece, if it does, replace
            //the uris.
            if self.all_course_info.len() == 0 {
                self.all_course_info.append().write(current_course_info);
            } else {
                for i in 0
                    ..self
                        .all_course_info
                        .len() {
                            if self
                                .all_course_info
                                .at(i)
                                .read()
                                .course_identifier == course_identifier {
                                self.all_course_info.at(i).uri.write(call_data);
                            } else {
                                self.all_course_info.append().write(current_course_info);
                            }
                        };
            };
            //run a loop to update the creator content storage data
            let mut i: u64 = 0;
            let vec_len = self.creator_to_all_content.entry(owner_).len();
            loop {
                if i >= vec_len {
                    break;
                }
                let content = self.creator_to_all_content.entry(owner_).at(i).read();
                if content.course_identifier == course_identifier {
                    self.creator_to_all_content.entry(owner_).at(i).uri.write(call_data);
                }
                i += 1;
            }
        }

        fn finish_course_claim_certification(ref self: ContractState, course_identifier: u256) {
            //only check for accessment score. that is if there's assesment
            //todo : verifier check, get a value from frontend, confirm the hash if it matches with
            //what is being saved. goal is to avoid fraudulent course claim.
            //todo issue certification. (whitelist address)
            self.completion_status.entry((get_caller_address(), course_identifier)).write(true);
            self.completed_courses.entry(get_caller_address()).append().write(course_identifier);
            let nft_contract_address = self.course_nft_contract_address.entry(course_identifier).read();
            
            let nft_dispatcher = super::IAttenSysNftDispatcher { contract_address: nft_contract_address };
            
            let nft_id = self.track_minted_nft_id.entry((course_identifier,nft_contract_address)).read();
            nft_dispatcher.mint(get_caller_address(), nft_id);
            self.track_minted_nft_id.entry((course_identifier,nft_contract_address)).write(nft_id + 1);
        }


        fn check_course_completion_status_n_certification(
            self: @ContractState, course_identifier: u256, candidate: ContractAddress
        ) -> bool {
            self.completion_status.entry((candidate, course_identifier)).read()
        }

        fn get_course_infos(
            self: @ContractState, course_identifiers: Array<u256>
        ) -> Array<Course> {
            let mut course_info_list: Array<Course> = array![];
            for element in course_identifiers {
                let mut data = self.specific_course_info_with_identifer.entry(element).read();
                course_info_list.append(data);
            };
            course_info_list
        }

        fn get_user_completed_courses(self: @ContractState, user: ContractAddress) -> Array<u256> {
            let vec = self.completed_courses.entry(user);
            let mut arr = array![];
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
                i += 1;
            };
            arr
        }

        fn get_all_courses_info(self: @ContractState) -> Array<Course> {
            let mut arr = array![];
            for i in 0
                ..self.all_course_info.len() {
                    arr.append(self.all_course_info.at(i).read());
                };
            arr
        }

        fn get_all_creator_courses(self: @ContractState, owner_: ContractAddress) -> Array<Course> {
            let vec = self.creator_to_all_content.entry(owner_);
            let mut arr = array![];
            let len = vec.len();
            let mut i: u64 = 0;
            loop {
                if i >= len {
                    break;
                }
                if let Option::Some(element) = vec.get(i) {
                    arr.append(element.read());
                }
                i += 1;
            };
            arr
        }

        fn get_creator_info(self: @ContractState, creator: ContractAddress) -> Creator {
            self.course_creator_info.entry(creator).read()
        }
    }
}
// probably something like

// #[starknet::contract]
// mod YourContract {
//     use starknet::ContractAddress;
//     use core::traits::Into;
//     use core::starknet::storage_access;
//     use core::array::ArrayTrait;
//     use starknet::storage::{Map, Vec, StoragePointerReadAccess, StoragePointerWriteAccess,
//     StoragePathEntry, VecTrait, MutableVecTrait};

//     #[storage]
//     struct Storage {
//         specific_video_course_uri_with_identifier: Map::<u256, Vec<felt252>>,
//     }

//     #[external(v0)]
//     fn set_course_uri(ref self: ContractState, course_identifier: u256, uri: Array<felt252>) {
//         let mut vec = self.specific_video_course_uri_with_identifier.entry(course_identifier);
//         for element in uri {
//             vec.append().write(element);
//         };
//     }

//     #[external(v0)]
//     fn get_course_uri(self: @ContractState, course_identifier: u256) -> Array<felt252> {
//         let vec = self.specific_video_course_uri_with_identifier.entry(course_identifier);
//         let mut array = ArrayTrait::new();
//         let len = vec.len();
//         let mut i: u64 = 0;
//         loop {
// if i >= len {
//     break;
// }
// if let Option::Some(element) = vec.get(i) {
//     array.append(element.read());
// }
// i += 1;
// };
//         array
//     }
// }

// you can combine each concept (storage, mapping, vec) etc together, make sure you understand the
// fundamentals first
// https://book.cairo-lang.org/ch14-01-00-contract-storage.html#modeling-of-the-contract-storage-in-the-core-library

// and then you can chat with the chatbot to iteratively build what you want

// my guess is just you're not importing all the required traits

// fn remove_at_index<T, impl TCopy: Copy<T>>(arr: @Array<T>, index: usize) -> Array<T> {
//     let mut new_arr = ArrayTrait::new();
//     let len = arr.len();

//     let mut i: usize = 0;
//     loop {
//         if i == len {
//             break;
//         }
//         if i != index {
//             new_arr.append(*arr.at(i));
//         }
//         i += 1;
//     };

//     new_arr
// }

// #[generate_trait]
// impl InternalFunctions of InternalFunctionsTrait {
//     fn clear_info(ref self: ContractState) {
//         let mut index = 0;
//         while index < self.all_course_info.len() {
//             self.all_course_info.pop_front();
//             index += 1;
//         }
//     }
// }

//signature
//     #[starknet::contract]
// mod SignatureVerifier {
//     use core::hash::LegacyHash;
//     use starknet::{ContractAddress, get_caller_address};
//     use core::ecdsa::check_ecdsa_signature;

//     #[storage]
//     struct Storage {
//         signature_counts: LegacyMap::<ContractAddress, u32>,
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     enum Event {
//         SignatureVerified: SignatureVerified,
//     }

//     #[derive(Drop, starknet::Event)]
//     struct SignatureVerified {
//         signer: ContractAddress,
//         count: u32,
//     }

//     #[external(v0)]
//     fn verify_signature(
//         ref self: ContractState,
//         message_hash: felt252,
//         signature: (felt252, felt252),
//         public_key: felt252
//     ) -> bool {
//         // Verify the signature
//         let is_valid = check_ecdsa_signature(
//             message_hash: message_hash,
//             public_key: public_key,
//             signature_r: signature.0,
//             signature_s: signature.1
//         );

//         if is_valid {
//             // Get the signer's address from the public key
//             let signer = get_address_from_public_key(public_key);

//             // Increment the signature count for this address
//             let mut count = self.signature_counts.read(signer);
//             count += 1;
//             self.signature_counts.write(signer, count);

//             // Emit an event
//             self.emit(Event::SignatureVerified(SignatureVerified { signer, count }));
//         }

//         is_valid
//     }

//     #[external(v0)]
//     fn get_signature_count(self: @ContractState, address: ContractAddress) -> u32 {
//         self.signature_counts.read(address)
//     }

//     fn get_address_from_public_key(public_key: felt252) -> ContractAddress {
//         // This is a simplified version. In a real implementation,
//         // you would derive the address from the public key using a proper hashing algorithm.
//         ContractAddress::try_from(public_key).unwrap()
//     }
// }


