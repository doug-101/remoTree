// sort_rule.dart, defines file sorting paramters and functions.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:path/path.dart' as p;
import 'file_item.dart';
import '../main.dart' show prefs;

enum SortType { name, extension, modified, size }

enum SortDirection { ascending, descending }

/// Stores sorting parmeters and supplies sorting functions.
class SortRule {
  late final SortType sortType;
  late final SortDirection sortDirection;

  SortRule(this.sortType, this.sortDirection);

  SortRule.fromPrefs() {
    try {
      sortType = SortType.values.firstWhere(
        (e) => e.name == (prefs.getString('sort_type') ?? ''),
      );
      sortDirection = SortDirection.values.firstWhere(
        (e) => e.name == (prefs.getString('sort_direction') ?? ''),
      );
    } on StateError {
      sortType = SortType.name;
      sortDirection = SortDirection.ascending;
    }
  }

  Comparator<FileItem> comparator() {
    return (a, b) {
      var result = switch (sortType) {
        SortType.name =>
          a.filename.toLowerCase().compareTo(b.filename.toLowerCase()),
        SortType.extension => p
            .extension(a.filename)
            .toLowerCase()
            .compareTo(p.extension(b.filename).toLowerCase()),
        SortType.modified => a.modTime.compareTo(b.modTime),
        SortType.size => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0),
      };
      if (sortDirection == SortDirection.descending) result *= -1;
      if ((sortType == SortType.extension || sortType == SortType.size) &&
          result == 0) {
        // Sort non-directory parameters by name to break ties.
        result = a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      }
      return result;
    };
  }
}
