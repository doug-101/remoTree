// host_data.dart, stores info for a server.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

/// Stores all info needed for an SSH/SFTP server.
class HostData {
  String displayName;
  String userName;
  String address;
  String? key;

  HostData(this.displayName, this.userName, this.address);

  /// Constructor for storage in preferences.
  HostData.fromJson(Map<String, dynamic> jsonData)
      : displayName = jsonData['display_name'],
        userName = jsonData['user_name'],
        address = jsonData['address'],
        key = jsonData['key'];

  HostData.copy(HostData other)
      : displayName = other.displayName,
        userName = other.userName,
        address = other.address,
        key = other.key;

  String get nameAndAddress => '$userName@$address';

  /// Save to JSON for preference storage.
  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{
      'display_name': displayName,
      'user_name': userName,
      'address': address
    };
    if (key != null) {
      result['key'] = key;
    }
    return result;
  }

  /// Defined to allow use in a set or map.
  @override
  bool operator ==(Object other) {
    return other is HostData &&
        displayName == other.displayName &&
        userName == other.userName &&
        address == other.address &&
        key == other.key;
  }

  /// Defined to allow use in a set or map.
  @override
  int get hashCode =>
      Object.hash(displayName, userName, address, key);
}
