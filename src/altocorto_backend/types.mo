
module {
    
    public type User = {
        name: Text;
        email: ?Text;
        avatar: ?Blob;
        videos: [VideoId] //
    };

    public type VideoId = Nat;

    public type Video = {
        title: Text;
        owner: Principal;
        videoSize: Nat;
        visible: Bool;
        chunksQty: Nat;
        chunkSize: Nat;
        data: [Chunk]
    };

    public type TempVideo = {
        title: Text;
        owner: Principal;
        videoSize: Nat;
        visible: Bool;
        chunksQty: Nat;
        chunkSize: Nat;
        data: [var Chunk]
    };

    public type UploadResponse = {
        #Ok: {tempId: Nat;
        chunksQty: Nat;
        chunkSize: Nat;};
        #Err;
    };

    public type Chunk = Blob;


}