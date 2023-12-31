// file_item.dart, contains data about each remote file.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

enum FileType { directory, file, link, other }

/// Stores information needed for a remote or local file.
class FileItem {
  final String path;
  final String filename;
  final FileType type;
  late final DateTime modTime;
  // [fileSize] is null for a directory or link.
  String? fileSize;
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
      fileSize = sizeStringFromBytes(stat.size);
    }
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
      fileSize = sizeStringFromBytes(fileInfo.attr.size ?? 0);
    }
  }
}

/// Return items from the tree if open.
Iterable<FileItem> itemGenerator(FileItem item,
    {bool showDotFiles = false, int level = 0}) sync* {
  item.level = level;
  if (item.filename != '.' &&
      item.filename != '..' &&
      (showDotFiles || !item.filename.startsWith('.'))) {
    yield item;
    if (item.isOpen) {
      for (var child in item.children) {
        yield* itemGenerator(child, level: level + 1);
      }
    }
  }
}

/// Return a human readable file size string.
String sizeStringFromBytes(int bytes) {
  switch (bytes) {
    case < 1000:
      return '${bytes}B';
    case < 1e6:
      return '${(bytes / 1000).toStringAsFixed(1)}K';
    case < 1e9:
      return '${(bytes / 1e6).toStringAsFixed(1)}M';
    case < 1e12:
      return '${(bytes / 1e9).toStringAsFixed(1)}G';
    default:
      return '${(bytes / 1e12).toStringAsFixed(1)}T';
  }
}
