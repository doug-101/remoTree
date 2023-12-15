// file_item.dart, contains data about each remote file.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:dartssh2/dartssh2.dart';

class FileItem {
  final String path;
  final String filename;
  final SftpFileType type;
  final children = <FileItem>[];
  bool isOpen = false;
  int level = 0;

  FileItem(this.path, this.filename, this.type);
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
