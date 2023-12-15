// connection.dart, top level model for remote connections.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'connect_data.dart';
import 'file_item.dart';
import '../main.dart' show prefs;

class Connection extends ChangeNotifier {
  final connectDataSet = <ConnectData>{};
  String? currentConnectName;
  SSHClient? _sshClient;
  SftpClient? _sftpClient;
  String? rootPath;
  final rootItems = <FileItem>[];

  Connection() {
    for (var data in prefs.getStringList('connections') ?? <String>[]) {
      connectDataSet.add(ConnectData.fromJson(json.decode(data)));
    }
  }

  List<ConnectData> get sortedConnectData {
    final dataList = List.of(connectDataSet);
    dataList.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return dataList;
  }

  void _storeConnectData() async {
    prefs.setStringList(
      'connections',
      List.of(connectDataSet.map((data) => json.encode(data.toJson()))),
    );
    notifyListeners();
  }

  void replaceConnectData(
    ConnectData oldConnectData,
    ConnectData newConnectData,
  ) {
    connectDataSet.remove(oldConnectData);
    connectDataSet.add(newConnectData);
    _storeConnectData();
  }

  void addConnectData(ConnectData newConnectData) {
    connectDataSet.add(newConnectData);
    _storeConnectData();
  }

  void deleteConnectData(ConnectData connectData) {
    connectDataSet.remove(connectData);
    _storeConnectData();
  }

  Future<void> connectToClient({
    required ConnectData connectData,
    required SSHPasswordRequestHandler passwordFunction,
  }) async {
    _sshClient = SSHClient(
      await SSHSocket.connect(connectData.address, 22),
      username: connectData.userName,
      onPasswordRequest: passwordFunction,
    );
    _sftpClient = await _sshClient!.sftp();
    rootPath = await _sftpClient!.absolute('.');
    currentConnectName = connectData.displayName;
    fetchRootFiles();
  }

  Future<void> fetchRootFiles() async {
    final sftpItems = await _sftpClient!.listdir(rootPath!);
    rootItems.clear();
    rootItems.addAll(
      sftpItems.map((i) => FileItem(rootPath!, i.filename, i.attr.type!)),
    );
    rootItems.sort(
      (a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()),
    );
    notifyListeners();
  }

  Future<void> toggleItemOpen(FileItem item) async {
    if (item.type == SftpFileType.directory ||
        item.type == SftpFileType.symbolicLink) {
      item.isOpen = !item.isOpen;
      if (item.isOpen && item.children.isEmpty) {
        final path = '${item.path}/${item.filename}';
        final sftpItems = await _sftpClient!.listdir(path);
        item.children.addAll(
            sftpItems.map((i) => FileItem(path, i.filename, i.attr.type!)));
        item.children.sort((a, b) =>
            a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));
      }
      notifyListeners();
    }
  }
  
  List<String> splitRootPath() {
    final parts = rootPath!.split('/');
    // Use connection nme for / directory.
    parts[0] = currentConnectName!;
    return parts;
  }

  void changeRootPath(String newPath) {
    rootPath = newPath;
    fetchRootFiles();
  }

  void closeConnection() {
    _sftpClient!.close();
    _sshClient!.close();
  }
}
