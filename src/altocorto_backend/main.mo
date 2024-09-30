import Map "mo:map/Map";
import {phash; nhash} "mo:map/Map";
import Types "types";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
actor {

    type User = Types.User;
    type VideoId = Types.VideoId;
    type Video = Types.Video;
    type TempVideo = Types.TempVideo;
    type UploadResponse = Types.UploadResponse;
    type Chunk = Types.Chunk;

    stable let users = Map.new<Principal, User>();
    stable let videos = Map.new<VideoId, Video>();
    stable var lastVideoId = 0;
    var tempUploadVideo = Map.new<Nat, TempVideo>();
    var tempFileId = 0; 

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

    public shared query ({ caller }) func logIn(): async ?User {
        Map.get<Principal, User>(users, phash, caller); 
    };

    public shared ({caller}) func uploadRequest(fileName : Text, fileSize : Nat, visible: Bool) : async UploadResponse {
        let user = Map.get<Principal, User>(users, phash, caller);
        switch user{
            case null {return #Err};
            case (?user) {
                let chunkSize = 1_000_000;   // Tamaño en Bytes de los "Chuncks" 1_048_576 //1MB
                let chunksQty = fileSize / chunkSize + (if (fileSize % chunkSize > 0) {1} else {0});
                let data = Prim.Array_init<Blob>(chunksQty, "");
                let id = tempFileId;
                tempFileId += 1;
                let newAsset: TempVideo = {
                    title = fileName;
                    owner = caller;
                    videoSize = fileSize;
                    visible;
                    chunksQty;
                    chunkSize;
                    data;
                };
                ignore Map.put<Nat, TempVideo>(tempUploadVideo, nhash, id, newAsset);
                let videos = Prim.Array_tabulate<VideoId>(user.videos.size() + 1, func (x): VideoId {
                    if (x == 0) { id } else { user.videos[x-1]}
                });
                ignore Map.put<Principal, User>(users, phash, caller, {user with videos});
                return #Ok({tempId = id; chunksQty = chunksQty; chunkSize = chunkSize;})
            }
        }
        
    };

    public shared ({ caller }) func uploadRequestNonUserFoTest(fileName : Text, fileSize : Nat): async UploadResponse {
        let chunkSize = 1_048_576;   // Tamaño en Bytes de los "Chuncks" 1_048_576 //1MB
        let chunksQty = fileSize / chunkSize + (if (fileSize % chunkSize > 0) {1} else {0});
        let data = Prim.Array_init<Blob>(chunksQty, "");
        let id = tempFileId;
        tempFileId += 1;
        let newAsset: TempVideo = {
            title = fileName;
            owner = caller;
            videoSize = fileSize;
            visible = true;
            chunksQty;
            chunkSize;
            data;
        };
        ignore Map.put<Nat, TempVideo>(tempUploadVideo, nhash, id, newAsset);
        return #Ok({tempId = id; chunksQty = chunksQty; chunkSize = chunkSize;})
    };

    public shared ({ caller }) func addChunk(tempFileId: Nat, chunk: Chunk, index: Nat ):async {#Ok; #Err: Text}{
        let tempFile = Map.get(tempUploadVideo, nhash, tempFileId);
        switch tempFile {
            case null {#Err("Archivo de carga no encontrado")};
             case (?tempFile) {
                if(tempFile.owner != caller){
                    return #Err("Usuario no autorizado");
                };
                tempFile.data[index] := chunk;
                #Ok
            }
        }
    };
    
    func frezze<T>(arr: [var T]): [T]{  
        Prim.Array_tabulate<T>(arr.size(), func x = arr[x])
    };

    public shared ({ caller }) func commiUpload(fileId: Nat): async {#Ok: Nat; #Err: Text}{
        let video = Map.remove(tempUploadVideo, nhash, fileId);
        switch video {
            case null { 
                return #Err("No se encuentra el Id")
            };
            case (?video){
                if(video.owner != caller) { return #Err("Usuario no autorizado")};
                var size = 0;
                for (ch in video.data.vals()){
                    size += ch.size();
                };
                if(size != video.videoSize){
                    return #Err("Tamaño incorrecto");
                };
                let data = frezze<Chunk>(video.data);
                lastVideoId += 1;
                ignore Map.put<Nat, Video>(videos, nhash, lastVideoId, {video with data});
                #Ok(lastVideoId)
            }
        };    
    };


    public query func startPlay(_videoId : Nat) : async {#Ok: Video; #Err: Text} {
        let video = Map.get(videos, nhash, _videoId);
        switch video {
            case null { #Err("File Not Found") };
            case (?video) { #Ok({ video with data = [] }) }; //Devolvemos toda la metadata menos los fragmento del video
        };
    };

    public query func getChunk(_fileId : Nat, chunkIndex : Nat) : async {#Ok: Blob; #Err: Text} {
        let video = Map.get(videos, nhash, _fileId);
        switch video {
            case null { #Err("File Not Found") };
            case (?video) {
                #Ok(video.data[chunkIndex]);
            };
        };
    };

    public shared ({ caller }) func deleteVideo(id: Nat): async Bool {
        let video = Map.get<Nat, Video>(videos, nhash, id);
        switch video {
            case null {false};
            case(?video) {
                if(video.owner == caller) {
                    Map.delete<Nat, Video>(videos, nhash, id);
                    true
                } else {
                    false
                }
            }
        }
    };

    public shared ({ caller }) func garbageCollector(): async Nat {
        assert(Principal.isController(caller));
        var counterBytes = 0;
        for(temp in Map.vals(tempUploadVideo)){
            for(b in temp.data.vals()){
                counterBytes += b.size()
            }
        };
        tempUploadVideo := Map.new<Nat, TempVideo>();
        counterBytes
    };


};
