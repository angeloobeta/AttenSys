// AttenSys
// An innovative platform designed to streamline the issuance of educational certificates 
// and efficiently track attendance for a course or event. AttenSys enables institutions 
// to securely manage certifications, ensuring authenticity and transparency, 
// while simplifying the attendance marking process for seamless record-keeping 
// or course completion or event attendance. Whether you're issuing certificates 
// for courses, events, or workshops, AttenSys guarantees a secure, scalable, and user-friendly solution
// Online streaming


// explore the use of session keys, to further enhance the seamless integration.

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


//buy a course 
//pay to register event
//earn points for every course, event and attendance marked.