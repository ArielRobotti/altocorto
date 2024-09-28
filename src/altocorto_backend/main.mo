import Map "mo:map/Map";
import {phash} "mo:map/Map";
import Types "types";
actor {

    type User = Types.User;
    type VideoId = Types.VideoId;
    type Video = Types.Video;

    stable let users = Map.new<Principal, User>();
    stable let videos = Map.new<VideoId, Video>();

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
    };

    public shared ({ caller }) func logIn(): async ?User {
        Map.get<Principal, User>(users, phash, caller); 
    };


    
};
