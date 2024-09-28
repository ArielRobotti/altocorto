
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
        duration: Nat;
        owner: Principal;
        visibility: Bool;
        chunksQty: Nat;
        size: Nat;
        data: [Chunk]
    };

    public type Chunk = Blob;


}