import SharedTypes "../sharedTypes";

module {

    public type UID = SharedTypes.UID;
    public type AssetId = SharedTypes.UID;
    public type StorageLocation = SharedTypes.StorageLocation;

    public type Access = {
        #Public;
        #RestrictedTo: [Principal];
        #OnlyOwner;
    };

    public type AssetMetadata = {
        id: AssetId;
        title: Text;
        description: Text;
        tags: [Text];
        location: StorageLocation;
        owner: Principal;
        access: Access; 
    };
}