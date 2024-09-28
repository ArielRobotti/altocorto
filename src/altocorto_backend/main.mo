import Map "mo:map/Map";
import {phash} "mo:map/Map";
import Types "types";
actor {

    type User = Types.User;
    type VideoId = Types.VideoId;

    stable let users = Map.new<Principal, User>();

    func isUser(u: Principal): Bool{
        return switch( Map.get<Principal,User>(users, phash, u) ){
            case null { false };
            case (_) { true };
        }
    };

    public shared ({ caller }) func signUp(name: Text, email: ?Text, avatar: ?Blob): async User {
        assert(not isUser(caller));
        let newUser: User = {
            name = name;
            email = email;
            avatar = avatar;
            videos: [VideoId] = []};
        ignore Map.put<Principal, User>(users, phash, caller, newUser);
        newUser
    }
};
