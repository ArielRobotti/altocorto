import User "modules/user";

shared ({ caller = DEPLOYER }) persistent actor class () = this {

	let userDatabase = User.initState(DEPLOYER);
	

	//----------------  Users ----------------//

	public shared ({ caller }) func signUp({ name : Text; email : Text }) : async User.SignupResponse {
		User.signUp(userDatabase, caller, name, email);
	};

	public shared ({ caller }) func login() : async User.LoginResponse {
		User.login(userDatabase, caller);
	};

};
