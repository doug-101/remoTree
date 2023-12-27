// file_item.dart, contains data about each remote file.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

enum FileType { directory, file, link, other }

class FileItem {
  final String path;
  final String filename;
  final FileType type;
  final children = <FileItem>[];
  bool isOpen = false;
  int level = 0;

  FileItem(this.path, this.filename, this.type);

  FileItem.fromFileEntity(FileSystemEntity file)
      : path = p.dirname(file.path),
        filename = p.basename(file.path),
        type = switch (file) {
          (Directory d) => FileType.directory,
          (File f) => FileType.file,
          (Link l) => FileType.link,
          _ => FileType.other,
        };

  FileItem.fromSftp(this.path, SftpName fileInfo)
      : filename = fileInfo.filename,
        type = switch (fileInfo.attr.type) {
          SftpFileType.directory => FileType.directory,
          SftpFileType.regularFile => FileType.file,
          SftpFileType.symbolicLink => FileType.link,
          _ => FileType.other,
        };
}

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
