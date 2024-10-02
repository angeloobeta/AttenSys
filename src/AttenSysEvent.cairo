use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IAttenSysCourse<TContractState> {
    fn create_event(ref self: TContractState, owner_: ContractAddress, event_name: ByteArray, start_time: u256, end_time: u256);
    fn end_event(ref self: TContractState, event_identifier: u256);
    fn alter_start_end_time(ref self: TContractState, new_start_time: u256, new_end_time : u256);
    fn batch_certify_attendees(ref self: TContractState, attendees: Array<ContractAddress>);
    fn get_attendance_status(ref self: TContractState, attendee : ContractAddress);
    //function to create an event, ability to start and end event in the event struct, each event will have a unique ID
    //function to mark attendace, with signature. keep track of all addresses that have signed (implementing a gasless transaction from frontend);
    //function to batch issue attendance certificate for events
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
        all_attended_event : Map::<ContractAddress, Vec<EventStruct>>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct EventStruct {
        event_name : ByteArray,
        time : Time,
        active_status : bool,
        signature_count : u256,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct Time {
        start_time : u256,
        end_time : u256,
    }

}