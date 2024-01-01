// file_interface.dart, models for remote and local file connections.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
//import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'file_item.dart';
import 'host_data.dart';
import 'sort_rule.dart';

/// Base class common to remote and local classes.
abstract class FileInterface extends ChangeNotifier {
  String? currentConnectName;
  String? rootPath;
  final rootItems = <FileItem>[];
  late SortRule sortRule;

  Future<void> fetchRootFiles();

  Future<void> toggleItemOpen(FileItem item);

  /// Return path elements for use in breadcrumb navigation.
  List<String> splitRootPath() {
    if (rootPath == null) return <String>[];
    final parts = rootPath!.split('/');
    // Use connection name for / directory.
    parts[0] = currentConnectName!;
    return parts;
  }

  /// Change to the new root path and reload contents.
  void changeRootPath(String newPath) {
    rootPath = newPath;
    fetchRootFiles();
  }

  /// Change sort rule and update stored children.
  void changeSortRule(SortRule newRule) {
    sortRule = newRule;
    rootItems.sort(sortRule.comparator());
    for (var root in rootItems) {
      for (var item in allItemGenerator(root, withChilrenOnly: true)) {
        item.children.sort(sortRule.comparator());
      }
    }
    notifyListeners();
  }

  /// Reset stored items to initial values.
  void closeConnection() {
    currentConnectName = null;
    rootPath = null;
    rootItems.clear();
  }
}

/// Superclass for SFTP connections.
class RemoteInterface extends FileInterface {
  String? currentConnectName;
  SSHClient? sshClient;
  SftpClient? _sftpClient;
  String? rootPath;
  final rootItems = <FileItem>[];
  SortRule sortRule;

  RemoteInterface() : sortRule = SortRule.fromPrefs();

  /// Make connection to given host and reload contents.
  Future<void> connectToClient({
    required HostData hostData,
    required SSHPasswordRequestHandler passwordFunction,
  }) async {
    sshClient = SSHClient(
      await SSHSocket.connect(hostData.address, 22),
      username: hostData.userName,
      onPasswordRequest: passwordFunction,
    );
    _sftpClient = await sshClient!.sftp();
    rootPath = await _sftpClient!.absolute('.');
    currentConnectName = hostData.displayName;
    fetchRootFiles();
  }

  /// Retrieve file info at the root level.
  @override
  Future<void> fetchRootFiles() async {
    rootItems.clear();
    final sftpItems = await _sftpClient!.listdir(rootPath!);
    rootItems.addAll(sftpItems.map((i) => FileItem.fromSftp(rootPath!, i)));
    rootItems.sort(sortRule.comparator());
    notifyListeners();
  }

  /// Toggle given directory open and load children if needed.
  @override
  Future<void> toggleItemOpen(FileItem item) async {
    if (item.type == FileType.directory || item.type == FileType.link) {
      item.isOpen = !item.isOpen;
      if (item.isOpen && item.children.isEmpty) {
        final path = '${item.path}/${item.filename}';
        final sftpItems = await _sftpClient!.listdir(path);
        item.children.addAll(sftpItems.map((i) => FileItem.fromSftp(path, i)));
        item.children.sort(sortRule.comparator());
      }
      notifyListeners();
    }
  }

  /// Reset stored items to initial values.
  @override
  void closeConnection() {
    super.closeConnection();
    _sftpClient?.close();
    sshClient?.close();
    _sftpClient = null;
    sshClient = null;
    notifyListeners();
  }
}

class LocalInterface extends FileInterface {
  String? currentConnectName = 'Local';
  String? rootPath;
  final rootItems = <FileItem>[];
  SortRule sortRule;

  /// Load local file info at startup.
  LocalInterface() : sortRule = SortRule.fromPrefs() {
    fetchRootFiles();
  }

  /// Retrieve file info at the root level.
  Future<void> fetchRootFiles() async {
    if (rootPath == null) {
      if (Platform.isAndroid) {
        rootPath = (await getExternalStorageDirectory())?.path;
      }
      if (rootPath == null) {
        // Use app directory if external storage isn't available.
        rootPath = (await getApplicationDocumentsDirectory()).path;
      }
      if (rootPath!.endsWith('/')) {
        // Remove trailing separator to make usable in [splitRootPath].
        rootPath = rootPath!.substring(0, rootPath!.length - 1);
      }
    }
    rootItems.clear();
    final items = Directory(rootPath!).listSync();
    rootItems.addAll(items.map((i) => FileItem.fromFileEntity(i)));
    rootItems.sort(sortRule.comparator());
    notifyListeners();
  }

  /// Toggle given directory open and load children if needed.
  Future<void> toggleItemOpen(FileItem item) async {
    if (item.type == FileType.directory || item.type == FileType.link) {
      item.isOpen = !item.isOpen;
      if (item.isOpen && item.children.isEmpty) {
        final path = '${item.path}/${item.filename}';
        final items = Directory(path).listSync();
        item.children.addAll(items.map((i) => FileItem.fromFileEntity(i)));
        item.children.sort(sortRule.comparator());
      }
      notifyListeners();
    }
  }
}
