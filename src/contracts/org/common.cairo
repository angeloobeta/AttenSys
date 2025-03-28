use core::starknet::{ContractAddress};

// Common data structures for AttenSys

#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct UserAttendedEventStruct {
    pub event_name: ByteArray,
    pub time: Time,
    pub event_organizer: ContractAddress,
    pub event_id: u256,
    pub event_uri: ByteArray,
}

#[event]
#[derive(Drop, starknet::Event)]
pub enum Event {
    Sponsor: Sponsor,
    Withdrawn: Withdrawn,
    EventCreated: EventCreated,
    EventEnded: EventEnded,
    AttendanceMarked: AttendanceMarked,
    RegisteredForEvent: RegisteredForEvent,
    RegistrationStatusChanged: RegistrationStatusChanged,
    AdminTransferred: AdminTransferred,
    AdminOwnershipClaimed: AdminOwnershipClaimed,
    BatchCertificationCompleted: BatchCertificationCompleted,
}


#[derive(Drop, Serde, starknet::Store)]
pub struct EventStruct {
    pub event_name: ByteArray,
    pub time: Time,
    pub active_status: bool,
    pub signature_count: u256,
    pub event_organizer: ContractAddress,
    pub registered_attendants: u256,
    pub event_uri: ByteArray,
    pub is_suspended: bool,
    pub event_id: u256,
    pub location: u8, // 0 represents online, 1 represents physical
    pub canceled: bool
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Time {
    pub registration_open: u8, //0 means false, 1 means true
    pub start_time: u256,
    pub end_time: u256,
}


#[derive(Drop, Clone, Serde, starknet::Store)]
pub struct AttendeeInfo {
    pub attendee_address: ContractAddress,
    pub attendee_uri: ByteArray,
}


#[derive(Drop, starknet::Event)]
pub struct Sponsor {
    pub amt: u256,
    pub uri: ByteArray,
    #[key]
    pub event: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Withdrawn {
    pub amt: u256,
    #[key]
    pub event: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct EventCreated {
    pub event_identifier: u256,
    pub event_name: ByteArray,
    pub event_organizer: ContractAddress,
    pub event_uri: ByteArray,
}

#[derive(Drop, starknet::Event)]
pub struct EventEnded {
    pub event_identifier: u256,
}

#[derive(Drop, starknet::Event)]
pub struct AttendanceMarked {
    pub event_identifier: u256,
    pub attendee: ContractAddress,
}


#[derive(Drop, starknet::Event)]
pub struct RegisteredForEvent {
    pub event_identifier: u256,
    pub attendee: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct RegistrationStatusChanged {
    pub event_identifier: u256,
    pub registration_open: u8,
}

#[derive(Drop, starknet::Event)]
pub struct AdminTransferred {
    pub old_admin: ContractAddress,
    pub new_admin: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AdminOwnershipClaimed {
    pub new_admin: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct BatchCertificationCompleted {
    pub event_identifier: u256,
    pub certified_attendees: Array<ContractAddress>,
}