// file_interface.dart, models for remote and local file connections.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2025, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show Utf8Codec;
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
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

  List<String> splitRootPath();

  Future<void> _fetchRootFiles();

  Future<void> _updateChildren(FileItem item);

  Future<Uint8List> _readFile(FileItem item);

  Future<void> _writeFile(FileItem parent, String filename, Uint8List data);

  Future<void> _createDirectory(String fullPath);

  Future<void> _deleteFiles(List<FileItem> selFiles);

  Future<void> _renameFile(FileItem item, String newName);

  Future<void> _changeFileMode(FileItem item, int newMode);

  Future<String> readFileAsString(FileItem item);

  Future<void> writeFileAsString(FileItem item, String data);

  Future<String> _linkPath(FileItem link);

  Future<String> _resolvePath(String path);

  /// Force an update of the views.
  void updateViews() {
    notifyListeners();
  }

  /// Change to the new root path and reload contents.
  Future<void> changeRootPath(String newPath) async {
    final origPath = rootPath;
    rootPath = await _resolvePath(newPath);
    try {
      await _fetchRootFiles();
    } on Exception {
      rootPath = origPath;
      await _fetchRootFiles();
      rethrow;
    }
    notifyListeners();
  }

  /// Toggle given directory open and load children if needed.
  Future<void> toggleItemOpen(FileItem item) async {
    if (item.type == FileType.directory || item.type == FileType.link) {
      if (!item.isOpen && item.children.isEmpty) {
        await _updateChildren(item);
      }
      // Set to open after update in case of error during update.
      item.isOpen = !item.isOpen;
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
          file.isRemote,
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

  /// Assign link target path and then update the view.
  void assignLinkPath(FileItem link) async {
    try {
      link.linkPath = await _linkPath(link);
      notifyListeners();
    } on FileSystemException {
      // Ignore error, usually on Windows.
    }
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
  SSHClient? sshClient;
  SftpClient? _sftpClient;
  SSHSession? _sshShell;
  final outputLines = <String>[''];
  static const maxLineLength = 100;
  // Set to true by frame view if the shell view needs to grab focus.
  var focusShellFlag = false;

  RemoteInterface() {
    super.sortRule = SortRule.fromPrefs();
  }

  bool get isClientConnected => sshClient != null;
  bool get isShellConnected => _sshShell != null;

  /// Make connection to given host.
  Future<void> connectToClient({
    required HostData hostData,
    required SSHPasswordRequestHandler passwordFunction,
    SSHPasswordRequestHandler? keyPassphraseFunction,
  }) async {
    String? passphrase;
    if (hostData.key != null &&
        keyPassphraseFunction != null &&
        SSHKeyPair.isEncryptedPem(hostData.key!)) {
      passphrase = await keyPassphraseFunction();
    }
    sshClient = SSHClient(
      await SSHSocket.connect(hostData.address, 22),
      username: hostData.userName,
      onPasswordRequest: passwordFunction,
      identities: hostData.key != null
          ? SSHKeyPair.fromPem(hostData.key!, passphrase)
          : null,
    );
    currentConnectName = hostData.displayName;
  }

  /// Create a key on the server.
  Future<void> createServerKey(HostData hostData, String passphrase) async {
    if (sshClient != null && _sftpClient == null) {
      _sftpClient = await sshClient!.sftp();
      String tmpDir = const Utf8Codec()
          .decode(await sshClient!.run('mktemp -d -p /tmp remotree-XXXXXX'))
          .trim();
      await sshClient!.run(
        'ssh-keygen -t rsa -q -f "$tmpDir/id_rsa" -N "$passphrase"',
      );
      hostData.key = await readFileAsString(
        FileItem(tmpDir, 'id_rsa', FileType.file, DateTime.now(), true),
      );
      await sshClient!.run(
        'mkdir -p ~/.ssh && chmod 700 ~/.ssh && '
        'cat $tmpDir/id_rsa.pub >> ~/.ssh/authorized_keys',
      );
      await sshClient!.run('rm -r $tmpDir');
    }
  }

  /// Add a string private key to the host.
  void addStringKey(HostData hostData, String keyString) {
    hostData.key = keyString;
  }

  /// Start the SSH client.
  ///
  /// Waits for connection to close before returning.
  Future<void> connectToShell() async {
    if (sshClient != null && _sshShell == null) {
      _sshShell = await sshClient!.shell(pty: const SSHPtyConfig(type: 'dumb'));
      _sshShell!.stdout.listen((data) {
        const debugMode = false;
        if (!debugMode) {
          var atCR = false;
          var inEsc = false;
          final line = <int>[];
          for (var i in data) {
            if (atCR && (i != 10 && i != 13)) {
              // Carriage return not followed by a line feed resets the line.
              line.clear();
              outputLines.last = '';
              atCR = false;
            }
            switch (i) {
              case 13:
                // Carriage return.
                atCR = true;
              case 10:
                // Line feed must only follow a CR.
                assert(atCR);
                if (inEsc) {
                  // Remove typical length of escaped characters.
                  line.removeRange(0, line.length > 7 ? 7 : line.length);
                  inEsc = false;
                }
                if (line.isNotEmpty) {
                  outputLines.last = const Utf8Codec().decode(line);
                  while (outputLines.last.length > maxLineLength) {
                    var nextLine = outputLines.last.substring(maxLineLength);
                    outputLines.last =
                        outputLines.last.substring(0, maxLineLength);
                    outputLines.add(nextLine);
                  }
                }
                outputLines.add('');
                line.clear();
                atCR = false;
              case 9:
                // Tab is replaced with two spaces.
                line.addAll([32, 32]);
              case 27:
                // Escape.
                inEsc = true;
              case 142:
              case 143:
              case 226:
                // Other control chars are skipped.
                continue;
              default:
                line.add(i);
            }
          }
          if (inEsc) {
            // Remove typical length of escaped characters.
            line.removeRange(0, line.length > 7 ? 7 : line.length);
          }
          outputLines.last = const Utf8Codec().decode(line);
          while (outputLines.last.length > maxLineLength) {
            var nextLine = outputLines.last.substring(maxLineLength);
            outputLines.last = outputLines.last.substring(0, maxLineLength);
            outputLines.add(nextLine);
          }
          // End non-debug mode.
        } else {
          // Start debug mode.
          final printables = <int>[];
          for (var i in data) {
            if (i > 31 && i < 127) {
              printables.add(i);
            } else {
              if (printables.isNotEmpty) {
                if (printables.every((i) => i == 32)) {
                  outputLines.add('<<<spaces>>>');
                } else {
                  outputLines.add(const Utf8Codec().decode(printables));
                }
                printables.clear();
              }
              final ch = switch (i) {
                10 => '<<LF>>',
                13 => '<<CR>>',
                27 => '<<ESC>>',
                142 => '<<SS2>>',
                143 => '<<SS3>>',
                226 => '<<??>>',
                _ => '<<<$i>>>'
              };
              outputLines.add(ch);
            }
          }
          if (printables.isNotEmpty) {
            if (printables.every((i) => i == 32)) {
              outputLines.add('<<<spaces>>>');
            } else {
              outputLines.add(const Utf8Codec().decode(printables));
            }
            printables.clear();
          }
          outputLines.add('<<<STOP>>>');
          // End debug mode.
        }
        notifyListeners();
      });
      _sshShell!.stderr.listen((data) {
        assert(true, 'Received Standard Error Content');
      });
      await _sshShell!.done;
      _sshShell = null;
      notifyListeners();
    }
  }

  /// Send the given string as a SSH command.
  void sendToShell(String cmd) {
    _sshShell!.write(const Utf8Codec().encode(cmd));
  }

  /// Start the SFTP client and reload contents.
  Future<void> connectToSftp() async {
    if (sshClient != null && _sftpClient == null) {
      _sftpClient = await sshClient!.sftp();
      rootPath = await _sftpClient!.absolute('.');
      await _fetchRootFiles();
      notifyListeners();
    }
  }

  /// Return path elements for use in breadcrumb navigation.
  @override
  List<String> splitRootPath() {
    if (rootPath == null) return <String>[];
    final parts = rootPath!.split('/');
    // Use connection name for / directory.
    parts[0] = currentConnectName!;
    return parts;
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
  @override
  Future<void> _renameFile(FileItem item, String newName) async {
    await _sftpClient!.rename(item.fullPath, '${item.path}/$newName');
  }

  /// Change the premissions of the given file.
  @override
  Future<void> _changeFileMode(FileItem item, int newMode) async {
    await _sftpClient!.setStat(
      item.fullPath,
      SftpFileAttrs(mode: SftpFileMode.value(newMode)),
    );
  }

  /// Read a file using a UTF-8 codec.
  @override
  Future<String> readFileAsString(FileItem item) async {
    final sftpFile =
        await _sftpClient!.open(item.fullPath, mode: SftpFileOpenMode.read);
    late final String strData;
    try {
      strData = await const Utf8Codec().decodeStream(sftpFile.read());
    } on FormatException {
      // Matches exception from a local file.
      throw const FileSystemException(
        "Failed to decode data using encoding 'utf-8'",
      );
    } finally {
      sftpFile.close();
    }
    return strData;
  }

  /// Write a file using a UFT-8 codec.
  @override
  Future<void> writeFileAsString(FileItem item, String data) async {
    final sftpFile = await _sftpClient!.open(
      item.fullPath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
    );
    await sftpFile.writeBytes(const Utf8Codec().encode(data));
    sftpFile.close();
  }

  /// Return the target path from a link.
  @override
  Future<String> _linkPath(FileItem link) async {
    return _sftpClient!.readlink(link.fullPath);
  }

  /// Return an absolute path with symlinks resolved.
  @override
  Future<String> _resolvePath(String path) async {
    return _sftpClient!.absolute(path);
  }

  /// Reset stored items to initial values.
  @override
  void closeConnection() {
    super.closeConnection();
    _sftpClient?.close();
    sshClient?.close();
    _sshShell?.close();
    outputLines.clear();
    outputLines.add('');
    _sftpClient = null;
    sshClient = null;
    _sshShell = null;
    notifyListeners();
  }
}

class LocalInterface extends FileInterface {
  /// Load local file info at startup.
  LocalInterface() {
    super.currentConnectName = 'Local';
    super.sortRule = SortRule.fromPrefs();
  }

  Future<void> initialFileLoad() async {
    await _fetchRootFiles();
    notifyListeners();
  }

  /// Return path elements for use in breadcrumb navigation.
  @override
  List<String> splitRootPath() {
    if (rootPath == null) return <String>[];
    final parts = rootPath!.split(Platform.pathSeparator);
    // Use connection name for / directory.
    parts[0] = currentConnectName!;
    return parts;
  }

  /// Retrieve file info at the root level.
  @override
  Future<void> _fetchRootFiles() async {
    if (rootPath == null) {
      if (Platform.isAndroid) {
        // Use ExternalPath, since path_provider just gives local app dirs.
        rootPath = (await ExternalPath.getExternalStorageDirectories())[0];
      }
      // Use app directory if external storage isn't available.
      rootPath ??= (await getApplicationDocumentsDirectory()).path;
      if (rootPath!.endsWith(Platform.pathSeparator)) {
        // Remove trailing separator to make usable in [splitRootPath].
        rootPath = rootPath!.substring(0, rootPath!.length - 1);
      }
    }
    rootItems.clear();
    final items = Directory(rootPath!).listSync(followLinks: false);
    rootItems.addAll(items.map((i) => FileItem.fromFileEntity(i)));
    rootItems.sort(sortRule.comparator());
  }

  /// Update children of given directory.
  @override
  Future<void> _updateChildren(FileItem item) async {
    item.children.clear();
    final items = Directory(item.fullPath).listSync(followLinks: false);
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
    File('${parent.fullPath}${Platform.pathSeparator}$filename')
        .writeAsBytes(data);
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
  @override
  Future<void> _renameFile(FileItem item, String newName) async {
    if (item.type == FileType.directory) {
      await Directory(item.fullPath)
          .rename('${item.path}${Platform.pathSeparator}$newName');
    } else {
      await File(item.fullPath)
          .rename('${item.path}${Platform.pathSeparator}$newName');
    }
  }

  /// Change the premissions of the given file.
  @override
  Future<void> _changeFileMode(FileItem item, int newMode) async {
    // No operation - can't change mode on local files in dart io.
  }

  /// Read a file using a UTF-8 codec.
  @override
  Future<String> readFileAsString(FileItem item) async {
    return File(item.fullPath).readAsString();
  }

  /// Write a file using a UFT-8 codec.
  @override
  Future<void> writeFileAsString(FileItem item, String data) async {
    await File(item.fullPath).writeAsString(data);
  }

  /// Return the target path from a link.
  @override
  Future<String> _linkPath(FileItem link) async {
    return Link(link.fullPath).target();
  }

  /// Return an absolute path with symlinks resolved.
  @override
  Future<String> _resolvePath(String path) async {
    return File(path).resolveSymbolicLinks();
  }
}
