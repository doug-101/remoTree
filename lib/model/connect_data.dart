// connect_data.dart, stores info for a server.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

class ConnectData {
  String displayName;
  String userName;
  String address;

  ConnectData(this.displayName, this.userName, this.address);

  ConnectData.fromJson(Map<String, dynamic> jsonData)
      : displayName = jsonData['display_name'],
        userName = jsonData['user_name'],
        address = jsonData['address'];

  ConnectData.copy(ConnectData other)
      : displayName = other.displayName,
        userName = other.userName,
        address = other.address;

  String get nameAndAddress => '$userName@$address';

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{
      'display_name': displayName,
      'user_name': userName,
      'address': address
    };
    return result;
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectData &&
        this.displayName == other.displayName &&
        this.userName == other.userName &&
        this.address == other.address;
  }

  @override
  int get hashCode =>
      Object.hash(this.displayName, this.userName, this.address);
}
