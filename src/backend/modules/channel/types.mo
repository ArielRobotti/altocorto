import SharedTypes "../sharedTypes";
import Map "mo:map/Map";

module {

  public type  UID = SharedTypes.UID;
  public type AssetId = SharedTypes.UID;

  public type ChannelMap = Map.Map<UID, Channel>;

  public type Channel = {
    owner : Principal;
    title : Text;
    description : Text;
    logo : ?Blob;
    banner : ?Blob;
    recoveryEmail : ?Text;
    content: [AssetId];
    extraData : SharedTypes.MetadataArray;
  };
};
