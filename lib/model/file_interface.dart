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

  Future<void> _fetchRootFiles();

  Future<void> _updateChildren(FileItem item);

  Future<Uint8List> _readFile(FileItem item);

  Future<void> _writeFile(FileItem parent, String filename, Uint8List data);

  Future<void> _createDirectory(String fullPath);

  Future<void> _deleteFiles(List<FileItem> selFiles);

  Future<void> _renameFile(FileItem item, String newName);

  Future<void> _changeFileMode(FileItem item, int newMode);

  /// Return path elements for use in breadcrumb navigation.
  List<String> splitRootPath() {
    if (rootPath == null) return <String>[];
    final parts = rootPath!.split('/');
    // Use connection name for / directory.
    parts[0] = currentConnectName!;
    return parts;
  }

  /// Change to the new root path and reload contents.
  Future<void> changeRootPath(String newPath) async {
    rootPath = newPath;
    await _fetchRootFiles();
    notifyListeners();
  }

  /// Toggle given directory open and load children if needed.
  Future<void> toggleItemOpen(FileItem item) async {
    if (item.type == FileType.directory || item.type == FileType.link) {
      item.isOpen = !item.isOpen;
      if (item.isOpen && item.children.isEmpty) {
        await _updateChildren(item);
      }
      notifyListeners();
    }
  }

  /// Refresh file list to get file system changes.
  Future<void> refreshFiles() async {
    final openPaths = <String>{};
    for (var root in rootItems) {
      for (var item in openItemGenerator(root, hideDotFiles: false)) {
        if (item.isOpen) {
          openPaths.add(item.fullPath);
        }
      }
    }
    await _fetchRootFiles();
    for (var root in rootItems) {
      if (openPaths.contains(root.fullPath)) {
        root.isOpen = true;
      }
      for (var item in openItemGenerator(root, hideDotFiles: false)) {
        if (item.type == FileType.directory) {
          if (openPaths.contains(item.fullPath)) {
            item.isOpen = true;
            await _updateChildren(item);
          }
        }
      }
    }
    notifyListeners();
  }

  /// Change sort rule and update stored children.
  void changeSortRule(SortRule newRule) {
    sortRule = newRule;
    rootItems.sort(sortRule.comparator());
    for (var root in rootItems) {
      for (var item in allItemGenerator(root, withChildrenOnly: true)) {
        item.children.sort(sortRule.comparator());
      }
    }
    notifyListeners();
  }

  /// Return selection list with nested items removed.
  List<FileItem> _unnestedSelectList(List<FileItem> selList) {
    final dirPaths = selList
        .where((i) => i.type == FileType.directory)
        .map((i) => i.fullPath);
    final unnestedItems =
        selList.where((i) => !dirPaths.any((d) => i.path.startsWith(d)));
    return List.of(unnestedItems);
  }

  /// Copy files from the given source into the destination & make updates.
  Future<void> copyFileOperation(
    FileInterface sourceModel,
    List<FileItem> sourceFiles,
    FileItem destinationDir,
  ) async {
    await _copyFiles(
        sourceModel, _unnestedSelectList(sourceFiles), destinationDir);
    destinationDir.isOpen = true;
    notifyListeners();
  }

  /// Copy files and recursive directories from the source to the destination.
  Future<void> _copyFiles(
    FileInterface sourceModel,
    List<FileItem> sourceFiles,
    FileItem destinationDir,
  ) async {
    for (var file in sourceFiles) {
      if (file.type == FileType.directory) {
        await sourceModel._updateChildren(file);
        final newDir = FileItem(
          destinationDir.fullPath,
          file.filename,
          FileType.directory,
          DateTime.now(),
        );
        await _createDirectory(newDir.fullPath);
        await _copyFiles(sourceModel, file.children, newDir);
      } else {
        await _writeFile(
          destinationDir,
          file.filename,
          await sourceModel._readFile(file),
        );
      }
    }
    await _updateChildren(destinationDir);
  }

  /// Delete the given files and refresh the file data.
  Future<void> deleteItems(List<FileItem> selFiles) async {
    await _deleteFiles(_unnestedSelectList(selFiles));
    await refreshFiles();
    notifyListeners();
  }

  /// Rename the given file and update the data.
  Future<void> renameItem(FileItem item, String newName) async {
    await _renameFile(item, newName);
    item.filename = newName;
    notifyListeners();
  }

  /// Change the premissions of the given file and update the data.
  Future<void> changeItemMode(FileItem item, int newMode) async {
    await _changeFileMode(item, newMode);
    item.mode = newMode;
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
    await _fetchRootFiles();
    notifyListeners();
  }

  /// Retrieve file info at the root level.
  @override
  Future<void> _fetchRootFiles() async {
    rootItems.clear();
    final sftpItems = await _sftpClient!.listdir(rootPath!);
    sftpItems.removeWhere((i) => i.filename == '.' || i.filename == '..');
    rootItems.addAll(sftpItems.map((i) => FileItem.fromSftp(rootPath!, i)));
    rootItems.sort(sortRule.comparator());
  }

  /// Update children of given directory.
  @override
  Future<void> _updateChildren(FileItem item) async {
    item.children.clear();
    final sftpItems = await _sftpClient!.listdir(item.fullPath);
    sftpItems.removeWhere((i) => i.filename == '.' || i.filename == '..');
    item.children
        .addAll(sftpItems.map((i) => FileItem.fromSftp(item.fullPath, i)));
    item.children.sort(sortRule.comparator());
  }

  /// Read data from a single file for copying.
  @override
  Future<Uint8List> _readFile(FileItem item) async {
    final sftpFile =
        await _sftpClient!.open(item.fullPath, mode: SftpFileOpenMode.read);
    final data = await sftpFile.readBytes();
    sftpFile.close();
    return data;
  }

  /// Write a single file from data for copying.
  @override
  Future<void> _writeFile(
      FileItem parent, String filename, Uint8List data) async {
    final sftpFile = await _sftpClient!.open(
      '${parent.fullPath}/$filename',
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
    );
    await sftpFile.writeBytes(data);
    sftpFile.close();
  }

  /// Create the given directory.
  @override
  Future<void> _createDirectory(String fullPath) async {
    await _sftpClient!.mkdir(fullPath);
  }

  /// Delete the given items.
  @override
  Future<void> _deleteFiles(List<FileItem> selFiles) async {
    final directories = <FileItem>[];
    final files = <FileItem>[];
    for (var selItem in selFiles) {
      for (var item in allItemGenerator(selItem)) {
        if (item.type == FileType.directory) {
          await _updateChildren(item);
          directories.add(item);
        } else {
          files.add(item);
        }
      }
    }
    for (var file in files) {
      await _sftpClient!.remove(file.fullPath);
    }
    for (var dir in directories.reversed) {
      await _sftpClient!.rmdir(dir.fullPath);
    }
  }

  /// Rename the given file.
  Future<void> _renameFile(FileItem item, String newName) async {
    await _sftpClient!.rename(item.fullPath, '${item.path}/$newName');
  }

  /// Change the premissions of the given file.
  Future<void> _changeFileMode(FileItem item, int newMode) async {
    await _sftpClient!.setStat(
      item.fullPath,
      SftpFileAttrs(mode: SftpFileMode.value(newMode)),
    );
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
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _fetchRootFiles();
    notifyListeners();
  }

  /// Retrieve file info at the root level.
  @override
  Future<void> _fetchRootFiles() async {
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
  }

  /// Update children of given directory.
  @override
  Future<void> _updateChildren(FileItem item) async {
    item.children.clear();
    final items = Directory(item.fullPath).listSync();
    item.children.addAll(items.map((i) => FileItem.fromFileEntity(i)));
    item.children.sort(sortRule.comparator());
  }

  /// Read data from a single file for copying.
  @override
  Future<Uint8List> _readFile(FileItem item) async {
    return File(item.fullPath).readAsBytes();
  }

  /// Write a single file from data for copying.
  @override
  Future<void> _writeFile(
      FileItem parent, String filename, Uint8List data) async {
    File('${parent.fullPath}/$filename').writeAsBytes(data);
  }

  /// Create the given directory.
  @override
  Future<void> _createDirectory(String fullPath) async {
    await Directory(fullPath).create();
  }

  /// Delete the given items.
  @override
  Future<void> _deleteFiles(List<FileItem> selFiles) async {
    for (var selItem in selFiles) {
      if (selItem.type == FileType.directory) {
        await Directory(selItem.fullPath).delete(recursive: true);
      } else {
        await File(selItem.fullPath).delete(recursive: true);
      }
    }
  }

  /// Rename the given file.
  Future<void> _renameFile(FileItem item, String newName) async {
    if (item.type == FileType.directory) {
      await Directory(item.fullPath).rename('${item.path}/$newName');
    } else {
      await File(item.fullPath).rename('${item.path}/$newName');
    }
  }

  /// Change the premissions of the given file.
  Future<void> _changeFileMode(FileItem item, int newMode) async {
    // No operation - can't change mode on local files in dart io.
  }
}
