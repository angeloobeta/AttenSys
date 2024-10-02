// AttenSys
// An innovative platform designed to streamline the issuance of educational certificates 
// and efficiently track attendance for a course or event. AttenSys enables institutions 
// to securely manage certifications, ensuring authenticity and transparency, 
// while simplifying the attendance marking process for seamless record-keeping 
// or course completion or event attendance. Whether you're issuing certificates 
// for courses(courses have Online streaming feature), events, or workshops, AttenSys guarantees a secure, scalable, and user-friendly solution


//required
//1. create account by just signing, using their wallet address, no user information required

//FOR COURSE
//2. a function to create course with specified start and end period, along side the minimum 
//time that must have passed to ensure the person actually did the course and not cheat, also for each lecture passed,
// make a unique count for that course, with the video's uri, course ID, the owner of the course.
//and at the end of the course, claim certification after making all checks.
// a function to check authenticity of certification.

//FOR EVENT 
//3. a function to mark attendance, seamless integration with barcode, by just inputing your address into a csv file
//4. obtain all the addresses from the csv file and write a function to batch issue certification at a particular
// end period of the event.
//5. a function to check the authenticity of attendance

//FOR ORGANIZAION OR SCHOOL/
//6. a function to create a class. and each class's id unique, and each attendance secret hash can be revoked at the end of the class so that no one can
//sign the attendance...all they have to do is sign (figure out a way to use their signature to identify them and make necessary 
//batch marking).
// after class, has been created, a function to register for the class.
//7. a function to track student's everyday attendance for both the student and the class master.

//CERTIFICATION 
//8. a function to manage all certifications obtained from a course, an event(attendance and certificate),
// and attendance(attendance count, with the class attended and the certificate obtained) from a school..

//FOR THE EXPLORER
//9. should be able to track all events that has been created
//course created
//school registered
//attendance signed
//certification issued
//10. should be able to confirm the tx of issued certificates to confirm authenticity by merely searching.

//figure out how to use checkpoint for graphql explorer : https://docs.checkpoint.box/guides/quickstart




features include:
//create course and upload videos to the course folder created
//ability to stream the course
//buy a course/ courses can be made free too,
//after finishing a course, ability to claim certification
//earn points for every course, event and attendance marked.
//ability check certification and also track all activities being done on the platform, like who created an event, what course was created, what time, and the search option should be able to search for a certifaction issued, making it look like etherscan interface.FOR THE EXPLORER
//should be able to track all events that has been created, course created, school registered, attendance signed, certification issued

//register event, ability to register for event
//mark attendance barcode for event
//events created should have a personalized dashboard
//the personalized dashboard should have optins to track data of the numbr of attendees and their respective addresses
// ability to batch issue attendance certificate to all attendees
//each event should have an info page that holds all information about the event

//create organization/school page/bootcamp
//manage all course class (no class content here)
//ability to create class 
//ability for student to register for the class
//ability for students to mark attendance for classes registered for
//ability to start an end class. once class ends, no one can mark attendance.
//info page for the school, and respective classes under the school/organization/bootcamp

