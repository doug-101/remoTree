// file_item.dart, contains data about each remote file.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import 'file_interface.dart';

enum FileType { directory, file, link, other }

/// Stores information needed for a remote or local file.
class FileItem {
  final String path;
  String filename;
  final FileType type;
  late final DateTime modTime;
  // [fileSize] is null for a directory or link.
  int? fileSize;
  // [mode] and [accessTime] are null if not supported.
  int? mode;
  DateTime? accessTime;
  final children = <FileItem>[];
  bool isOpen = false;
  int level = 0;

  FileItem(this.path, this.filename, this.type, this.modTime);

  /// Constructor for local files.
  FileItem.fromFileEntity(FileSystemEntity file)
      : path = p.dirname(file.path),
        filename = p.basename(file.path),
        type = switch (file) {
          (Directory d) => FileType.directory,
          (File f) => FileType.file,
          (Link l) => FileType.link,
          _ => FileType.other,
        } {
    final stat = file.statSync();
    modTime = stat.modified;
    if (type == FileType.file) {
      fileSize = stat.size;
    }
    mode = stat.mode;
    accessTime = stat.accessed;
  }

  /// Constructor for remote files.
  FileItem.fromSftp(this.path, SftpName fileInfo)
      : filename = fileInfo.filename,
        type = switch (fileInfo.attr.type) {
          SftpFileType.directory => FileType.directory,
          SftpFileType.regularFile => FileType.file,
          SftpFileType.symbolicLink => FileType.link,
          _ => FileType.other,
        } {
    modTime = DateTime.fromMillisecondsSinceEpoch(
      (fileInfo.attr.modifyTime ?? 0) * 1000,
    );
    if (type == FileType.file) {
      fileSize = fileInfo.attr.size ?? 0;
    }
    mode = fileInfo.attr?.mode?.value;
    if (fileInfo.attr.accessTime != null) {
      accessTime = DateTime.fromMillisecondsSinceEpoch(
        (fileInfo.attr.accessTime!) * 1000,
      );
    }
  }

  /// The full path for this item.
  String get fullPath => '$path/$filename';

  /// Return the file size as a human readable string.
  ///
  /// Returns a zero size if [fileSize] is null.
  String get fileSizeString {
    switch (fileSize ?? 0) {
      case < 1000:
        return '${fileSize ?? 0}B';
      case < 1e6:
        return '${((fileSize ?? 0) / 1000).toStringAsFixed(1)}K';
      case < 1e9:
        return '${((fileSize ?? 0) / 1e6).toStringAsFixed(1)}M';
      case < 1e12:
        return '${((fileSize ?? 0) / 1e9).toStringAsFixed(1)}G';
      default:
        return '${((fileSize ?? 0) / 1e12).toStringAsFixed(1)}T';
    }
  }

  /// Return the file mode as a human readable string.
  ///
  /// Returns an empty string if [mode] is null.
  String get fileModeString {
    if (mode == null) return '';
    final permissions = mode! & 0xFFF;
    final codes = const [
      '---',
      '--x',
      '-w-',
      '-wx',
      'r--',
      'r-x',
      'rw-',
      'rwx',
    ];
    final result = [];
    if ((permissions & 0x800) != 0) result.add('(suid) ');
    if ((permissions & 0x400) != 0) result.add('(sgid) ');
    if ((permissions & 0x200) != 0) result.add('(sticky) ');
    result
      ..add(codes[(permissions >> 6) & 0x7])
      ..add(' ${codes[(permissions >> 3) & 0x7]} ')
      ..add(codes[permissions & 0x7]);
    return result.join();
  }
}

/// Return items from the tree if open and assign indent levels.
Iterable<FileItem> openItemGenerator(FileItem item,
    {bool hideDotFiles = true, int level = 0}) sync* {
  item.level = level;
  if (!hideDotFiles || !item.filename.startsWith('.')) {
    yield item;
    if (item.isOpen) {
      for (var child in item.children) {
        yield* openItemGenerator(
          child,
          hideDotFiles: hideDotFiles,
          level: level + 1,
        );
      }
    }
  }
}

/// Return all existing items from the tree.
Iterable<FileItem> allItemGenerator(FileItem item,
    {bool withChildrenOnly = false}) sync* {
  if (!withChildrenOnly || item.children.isNotEmpty) {
    yield item;
    for (var child in item.children) {
      yield* allItemGenerator(child, withChildrenOnly: withChildrenOnly);
    }
  }
}
