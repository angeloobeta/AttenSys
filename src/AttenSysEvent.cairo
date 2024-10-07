use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysEvent<TContractState> {
    fn create_event(ref self: TContractState, owner_: ContractAddress, event_name: ByteArray, start_time_: u256, end_time_: u256);
    fn alter_start_end_time(ref self: TContractState, new_start_time: u256, new_end_time : u256);
    fn batch_certify_attendees(ref self: TContractState, attendees: Array<ContractAddress>);
    fn mark_attendance(ref self: TContractState, event_identifier: u256);
    // fn get_attendance_status(ref self: TContractState, attendee: ContractAddress) -> bool;
    // fn get_all_attended_events(ref self: TContractState, user: ContractAddress)-> Array<AttenSysEvent::EventStruct>;
    
    //function to create an event, ability to start and end event in the event struct, each event will have a unique ID
    //function to mark attendace, with signature. keep track of all addresses that have signed (implementing a gasless transaction from frontend);
    //function to batch issue attendance certificate for events
    //function to transfer event ownership
}

#[starknet::contract]
mod AttenSysEvent {
    use core::starknet::{ContractAddress, get_caller_address};
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait
    };

    #[storage]
    struct Storage {
        //saves all event
        all_event : Vec<EventStruct>,
        //saves specific event
        specific_event_with_identifier : Map::<u256, EventStruct>,
        //saves attendees details for a particular event
        attendees_for_event_with_identifier : Map::<u256, Vec<ContractAddress>>,
        //event identifier
        event_identifier : u256,
        //saves attendance status
        attendance_status : Map::<(ContractAddress, u256), bool>,
        //saves all attended events
        all_attended_event : Map::<ContractAddress, Vec<UserAttendedEventStruct>>,
    }

    //create a separate struct for the all_attended_event that will only have the time the event took place and its name
    #[derive(Drop, Serde, starknet::Store)]
    pub struct EventStruct {
        event_name : ByteArray,
        time : Time,
        active_status : bool,
        signature_count : u256,
        event_organizer : ContractAddress,
    }

    #[derive(Drop,Copy,Serde, starknet::Store)]
    pub struct Time {
        start_time : u256,
        end_time : u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct UserAttendedEventStruct {
        event_name : ByteArray,
        time : u256,
    }


    #[abi(embed_v0)]
    impl IAttenSysEventImpl of super::IAttenSysEvent<ContractState> {
        fn create_event(ref self: ContractState, owner_: ContractAddress, event_name: ByteArray, start_time_: u256, end_time_: u256){
            let pre_existing_counter = self.event_identifier.read();
            let new_identifier = pre_existing_counter + 1;
            
            let time_data : Time = Time {
                start_time : start_time_,
                end_time : end_time_,
            };
            let event_call_data : EventStruct = EventStruct {
                event_name : event_name.clone(),
                time : time_data,
                active_status : true,
                signature_count : 0,
                event_organizer : owner_,
            };

            self.all_event.append().write(event_call_data);
            self.specific_event_with_identifier.entry(new_identifier).write(EventStruct{
                event_name : event_name,
                time : time_data,
                active_status : true,
                signature_count : 0,
                event_organizer : owner_,
            }
            );
            self.event_identifier.write(new_identifier);
        }

        fn alter_start_end_time(ref self: ContractState, new_start_time: u256, new_end_time : u256){
            //only event owner

        }

        fn batch_certify_attendees(ref self: ContractState, attendees: Array<ContractAddress>){
            //only event owner

        }

        fn mark_attendance(ref self: ContractState, event_identifier: u256){
            
        }

        // fn get_attendance_status(ref self: ContractState, attendee: ContractAddress) -> bool{

        // }

        // fn get_all_attended_events(ref self: ContractState, user: ContractAddress)-> Array<EventStruct>{

        // } 
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn end_event(ref self: ContractState, event_identifier: u256){
            let event_details = self.specific_event_with_identifier.entry(event_identifier).read();
            //only event owner
            assert(event_details.event_organizer == get_caller_address(), 'not authorized');

            let time_data : Time = Time {
                start_time : event_details.time.start_time,
                end_time : 0,
            };

            let event_call_data : EventStruct = EventStruct {
                event_name : event_details.event_name,
                time : time_data,
                active_status : false,
                signature_count : event_details.signature_count,
                event_organizer : event_details.event_organizer,
            };
            //reset specific event with identifier
            self.specific_event_with_identifier.entry(event_identifier).write(event_call_data);
            //loop through the all_event vec and end the specific event
            if self.all_event.len() > 0 {
                for i in 0..self.all_event.len() {

                }
            }
            
        }
    }
}