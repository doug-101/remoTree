// host_list.dart, model storing available remote connections.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'host_data.dart';
import '../main.dart' show prefs;

/// Strores host data for remote connections.
class HostList extends ChangeNotifier {
  final hostDataSet = <HostData>{};

  /// Reads hosts from preferences at startup.
  HostList() {
    for (var data in prefs.getStringList('hosts') ?? <String>[]) {
      hostDataSet.add(HostData.fromJson(json.decode(data)));
    }
  }

  /// Return a sorted list.
  List<HostData> get sortedHostData {
    final dataList = List.of(hostDataSet);
    dataList.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return dataList;
  }

  /// Store the hosts to preferences.
  void _storeHostData() async {
    prefs.setStringList(
      'hosts',
      List.of(hostDataSet.map((data) => json.encode(data.toJson()))),
    );
    notifyListeners();
  }

  /// Replace old host with an updated one.
  void replaceHostData(
    HostData oldHostData,
    HostData newHostData,
  ) {
    hostDataSet.remove(oldHostData);
    hostDataSet.add(newHostData);
    _storeHostData();
  }

  /// Add a new host data item.
  void addHostData(HostData newHostData) {
    hostDataSet.add(newHostData);
    _storeHostData();
  }

  /// Delete a host item.
  void deleteHostData(HostData hostData) {
    hostDataSet.remove(hostData);
    _storeHostData();
  }
}
