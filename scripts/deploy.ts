import { Account, CallData, Contract, RpcProvider, stark } from "starknet";
import * as dotenv from "dotenv";
import { getCompiledCode } from "./utils";
dotenv.config();


async function main() {
    const provider = new RpcProvider({
        nodeUrl: process.env.RPC_ENDPOINT,
    });

    console.log("ACCOUNT_ADDRESS=", process.env.DEPLOYER_ADDRESS);
    const privateKey0 = process.env.DEPLOYER_PRIVATE_KEY ?? "";
    const accountAddress0: string = process.env.DEPLOYER_ADDRESS ?? "";
    const account0 = new Account(provider, accountAddress0, privateKey0);
    console.log("Account connected.\n");

  
     let AsierraCode, AcasmCode, BsierraCode, BcasmCode, CsierraCode, CcasmCode;
    
     try {
        ({ AsierraCode, AcasmCode, BsierraCode, BcasmCode, CsierraCode, CcasmCode } = await getCompiledCode(
        "attendsys_AttenSysCourse","attendsys_AttenSysEvent","attendsys_AttenSysOrg" 
        ));
    } catch (error: any) {
        console.log("Failed to read contract files");
        console.log(error);
        process.exit(1);
    }

    const contract_owner = "0x64b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691"
    console.log("deploying attensys course.....\n");
    //for course 
    const CourseCallData = new CallData(AsierraCode.abi);
    const constructor_a = CourseCallData.compile("constructor", {
        owner: contract_owner,
    });

    const coursedeployResponse = await account0.declareAndDeploy({
        contract: AsierraCode,
        casm: AcasmCode,
        constructorCalldata: constructor_a,
        salt: stark.randomAddress(),
    });

       // Connect the new course contract instance :
       const AttensysCourseContract = new Contract(
        AsierraCode.abi,
        coursedeployResponse.deploy.contract_address,
        provider
    );

    console.log("deploying attensys event.....\n");
   //for event 
   const EventCallData = new CallData(BsierraCode.abi);
   const constructor_b = EventCallData.compile("constructor", {
       owner: contract_owner,
   });

   const eventdeployResponse = await account0.declareAndDeploy({
       contract: BsierraCode,
       casm: BcasmCode,
       constructorCalldata: constructor_b,
       salt: stark.randomAddress(),
   });

      // Connect the new contract instance :
      const AttensysEventContract = new Contract(
        BsierraCode.abi,
        eventdeployResponse.deploy.contract_address,
       provider
   ); 

   console.log("deploying attensys org.....\n");
   //for org 
   const OrgCallData = new CallData(CsierraCode.abi);
   const constructor_c = OrgCallData.compile("constructor", {
       owner: contract_owner,
   });

   const orgdeployResponse = await account0.declareAndDeploy({
       contract: CsierraCode,
       casm: CcasmCode,
       constructorCalldata: constructor_c,
       salt: stark.randomAddress(),
   });

      // Connect the new contract instance :
      const AttensysOrgContract = new Contract(
        CsierraCode.abi,
        orgdeployResponse.deploy.contract_address,
       provider
   );
   
   
   
   
    console.log(
        `✅ Attensys course deployed to address: ${AttensysCourseContract.address}`
    );
    console.log(
        `✅ Attensys Event deployed to address: ${AttensysEventContract.address}`
    ); 
    console.log(
        `✅ Attensys Org deployed to address: ${AttensysOrgContract.address}`
    );

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });