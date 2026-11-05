import Types "./types";
import { now } "mo:core/Time";
import Set "mo:map/Set";
import Map "mo:map/Map";
import { phash; thash } "mo:map/Map";
import SharedTypes "../sharedTypes";
import List "mo:core/List";
import Principal "mo:core/Principal";
import Int "mo:core/Int";
import Array "mo:core/Array";
// import { print } "mo:core/Debug";

module {
  public type User = Types.User;
  public type UserDB = Types.UserDB;
  public type Activitylog = SharedTypes.Activitylog;
  public type Activity = SharedTypes.Activity;
  public type SignupResponse = Types.SignupResponse;
  public type LoginResponse = Types.LoginResponse;
  public type UserDataInfo = Types.UserDataInfo;
  

  public func initState(deployer : Principal) : UserDB {
    let logEntry : Activity = {
      action = { actionName = "Init UserDB"; asociatedData = []; date = now() };
      user = deployer;
    };
    return {
      temporalCodes = Map.new<Principal, Types.CodeVerification>(); // Temporal Code Verifications
      timeoutCodeVerification = 2 * 60 * 1_000_000_000; // 2 * 60 * 1_000_000_000  = Dos minutos 
      admins = Set.make<Principal>(phash, deployer);
      blackList = Set.new<Text>();
      userActivityLog = List.fromArray<Activity>([logEntry]);
      users = Map.make<Principal, User>(phash, deployer, createUser("Admin", "",deployer ));
    };
  };

  public func generateCodeVerification(s: UserDB, caller : Principal, email: Text): Text { // Se devuelve provisoriamente pero en el flujo final se envia por email
    switch ( validateCaller(s, caller), validateEmail(s, email)) {
      case (#Ok, #Ok) {
        let codeVerification: Types.CodeVerification  =  {
          code = generateNDigitCode(6);
          generatedAt = now();
        };
        // TODO enviar email mediante https outcalls
        ignore Map.put<Principal, Types.CodeVerification>(s.temporalCodes, phash, caller, codeVerification);
        return codeVerification.code
      };
      case _ return ""
    }
  };
  
  public func validateCode(s: UserDB, caller: Principal, code: Text): Bool {
    switch (Map.remove<Principal, Types.CodeVerification>(s.temporalCodes, phash, caller)){
      case null return false;
      case (?userCode) {
        if ( userCode.code != code ) {
          // Si no es igual, caso menos probable, lo metemos otra vez en el mapa
          ignore Map.put<Principal, Types.CodeVerification>(s.temporalCodes, phash, caller, userCode);
          return false
        } else {
          if (now() > userCode.generatedAt + s.timeoutCodeVerification) {
            return false
          };
          return true
        }
      }
    };
  };

  public func signUp(s : UserDB, caller : Principal, name : Text, email: Text) : SignupResponse {
    assert(not Principal.isAnonymous(caller));
    ///// Validaciones /////
    switch (validateCaller(s, caller)) {
      case (#Err(e)) return #Err(e);
      case _ {}
    };

    switch (validateEmail(s, email)) {
      case (#Err(e)) return #Err(e);
      case _ {} 
    };
    /////// Fin validaciones /////

    let newUser = createUser(name, email, caller);
    ignore Map.put<Principal, User>(s.users, phash, caller, newUser);
    List.add<Activity>(
      s.userActivityLog,
      { action = newUser.lastAction; user = caller },
    );
    #Ok(newUser);
  };

  public func login(s : UserDB, caller : Principal) : LoginResponse {
    assert(not Principal.isAnonymous(caller));
    switch (Map.get<Principal, User>(s.users, phash, caller)) {
      case null { #Err("User not found") };
      case (?user) {
        let updatedUser : User = {
          user with
          lastAction : SharedTypes.Action = {
            date = now();
            actionName : Text = "Login";
            asociatedData = [];
          };
        };
        List.add<Activity>(
          s.userActivityLog,
          { action = updatedUser.lastAction; user = caller },
        );
        #Ok(updatedUser);
      };
    };
  };

  public func deleteUserAccount(s : UserDB, caller : Principal) : {
    #Ok;
    #Err : Text;
  } {
    if (not isUser(s, caller)) {
      return #Err("Caller is not an user");
    };
    if (isAdmin(s, caller) and Set.size(s.admins) == 1) {
      return #Err("The platform cannot be left without an administrator.");
    };
    ignore Set.remove<Principal>(s.admins, phash, caller);
    ignore Map.remove<Principal, User>(s.users, phash, caller);
    let logEntry : SharedTypes.Action = {
      date = now();
      actionName : Text = "deleteUserAccount";
      asociatedData = [];
    };
    List.add<Activity>(
      s.userActivityLog,
      { action = logEntry; user = caller },
    );
    return #Ok;
  };

  public func getBatchUserData(s: UserDB, users: [Principal]): [UserDataInfo] {
    func getInfo(principal: Principal): UserDataInfo {
      switch (Map.get(s.users, phash, principal)) {
        case null {{principal; name = ""; email = ""; avatar = null; verificated = false}};
        case (? user ) {
          user
        }
      }
    };
    Array.map<Principal, UserDataInfo>(users, getInfo)
  };

  ///////////////// Private functions /////////////////

  func generateNDigitCode(n: Int): Text {
    let code = now() % (10 ** n) + (if (now() % (10 ** n) < (10 ** n)) {10 ** (n-1)} else {0});
    Int.toText(code)
  };

  func validateCaller(s: UserDB, caller : Principal): {#Ok; #Err:Types.ErrorCaller} {
    if (Set.has(s.blackList, thash, Principal.toText(caller))) { 
      return #Err(#CallerInBlackList) 
    };
    if (isUser(s, caller)) { 
      return #Err(#CallerIsAlreadyUser) 
    };
    #Ok
  };

  func validateEmail(s: UserDB, email: Text):{#Ok; #Err:Types.ErrorEmail} {
    if (Set.has(s.blackList, thash, email)) { 
      return #Err(#EmailInBlackList) 
    };
    // TODO mapear en UserDB emails verificados para validar rapido usuario existente
    #Ok
  };

  func createUser(name : Text, email: Text, caller : Principal) : User {
    {
      email;
      verificated = false;
      lastAction : SharedTypes.Action = {
        date = now();
        actionName : Text = "SignUp";
        asociatedData = [
          ("name", #Text(name)),
          ("email", #Text(email))
        ];
      };
      metadataUser : SharedTypes.MetadataArray = [];
      name;
      paymentStatus : Types.PaymentStatus = {
        lastPaymentDate = 0;
        lastPaymentAmount = 0;
      };
      preferences : SharedTypes.MetadataArray = [];
      principal = caller;
      signUpDate : Int = now();
      avatar = null
    };
  };

  ///// Control access /////////

  public func isAdmin(s : UserDB, p : Principal) : Bool {
    Set.has<Principal>(s.admins, phash, p);
  };

  public func isUser(s : UserDB, p : Principal) : Bool {
    Map.has<Principal, User>(s.users, phash, p);
  };

  public func isVerificatedUser(s: UserDB, p : Principal ): Bool {
    if (isAdmin(s, p )) return true;
    switch (Map.get<Principal, User>(s.users, phash, p)) {
      case null { return false };
      // case ( ?user ) { user.verificated}; // Descomentar luego de implementar verificacion de correos
      case ( _ ) { true };
    }
  };

  /////// Admin functions //////////

  public func addAdmin(s : UserDB, caller : Principal, user : Principal) : Bool {
    if (not isAdmin(s, caller) or not isUser(s, user)) {
      return false;
    };
    let logEntry : SharedTypes.Action = {
      date = now();
      actionName : Text = "Add admin";
      asociatedData = [("newAdmin:", #Principal(user))];
    };
    List.add<Activity>(
      s.userActivityLog,
      { action = logEntry; user = caller },
    ); 
    ignore Set.put<Principal>(s.admins, phash, user);
    return true;
  };

  public func removeAdmin(s : UserDB, caller : Principal, user : Principal) : Bool {
    if (not isAdmin(s, caller)) {
      return false;
    };
    let logEntry : SharedTypes.Action = {
      date = now();
      actionName : Text = "Remove admin";
      asociatedData = [("Admin removed:", #Principal(user))];
    };
    List.add<Activity>( s.userActivityLog, { action = logEntry; user = caller } );
    ignore Set.remove<Principal>(s.admins, phash, user);
    return true;
  };

  //-------------------- Utils ----------------//
  public func toText(user: User): Text {
    Principal.toText(user.principal) # "\t" #
    user.name # "\t" #
    user.email # "\t" #
    Int.toText(user.paymentStatus.lastPaymentAmount) # "\t" #
    Int.toText(user.paymentStatus.lastPaymentDate) # "\t" #
    Int.toText(user.signUpDate/1_000_000_000) # "\t" #
    (if(user.verificated) {"true"} else {"false"})
  };

};
