// host_list.dart, model for remote connections.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'host_data.dart';
import '../main.dart' show prefs;

class HostList extends ChangeNotifier {
  final hostDataSet = <HostData>{};

  HostList() {
    for (var data in prefs.getStringList('hosts') ?? <String>[]) {
      hostDataSet.add(HostData.fromJson(json.decode(data)));
    }
  }

  List<HostData> get sortedHostData {
    final dataList = List.of(hostDataSet);
    dataList.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return dataList;
  }

  void _storeHostData() async {
    prefs.setStringList(
      'hosts',
      List.of(hostDataSet.map((data) => json.encode(data.toJson()))),
    );
    notifyListeners();
  }

  void replaceHostData(
    HostData oldHostData,
    HostData newHostData,
  ) {
    hostDataSet.remove(oldHostData);
    hostDataSet.add(newHostData);
    _storeHostData();
  }

  void addHostData(HostData newHostData) {
    hostDataSet.add(newHostData);
    _storeHostData();
  }

  void deleteHostData(HostData hostData) {
    hostDataSet.remove(hostData);
    _storeHostData();
  }
}
