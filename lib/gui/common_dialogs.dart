// common_dialogs.dart, several common dialog functions.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../model/sort_rule.dart';

/// Dialog with two buttons (OK and CANCEL by default) for confirmation.
Future<bool?> okCancelDialog({
  required BuildContext context,
  String title = 'Confirm?',
  String? label,
  String trueButtonText = 'OK',
  String falseButtonText = 'CANCEL',
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(label ?? ''),
        actions: <Widget>[
          TextButton(
            child: Text(trueButtonText),
            onPressed: () => Navigator.pop(context, true),
          ),
          TextButton(
            child: Text(falseButtonText),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      );
    },
  );
}

/// Dialog with an OK button to create a pause to inform the user.
Future<bool?> okDialog({
  required BuildContext context,
  String title = 'Confirm?',
  String? label,
  bool isDissmissable = true,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: isDissmissable,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(label ?? ''),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );
    },
  );
}

/// Dialog to select between the given choices.
Future<String?> choiceDialog({
  required BuildContext context,
  required List<String> choices,
  String title = 'Choose',
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return SimpleDialog(
        title: Text(title),
        children: <Widget>[
          for (var choice in choices)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, choice);
              },
              child: Text(choice),
            ),
        ],
      );
    },
  );
}

/// Dialog to select sorting method.
Future<SortRule?> sortRuleDialog({
  required BuildContext context,
  required SortRule initialRule,
}) async {
  return showDialog<SortRule>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      var sortType = initialRule.sortType;
      var sortDir = initialRule.sortDirection;
      return AlertDialog(
        title: const Text('Sorting Rule'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var item in SortType.values)
                  RadioListTile<SortType>(
                    title: Text(
                      '${item.name[0].toUpperCase()}${item.name.substring(1)}',
                    ),
                    value: item,
                    groupValue: sortType,
                    onChanged: (SortType? value) {
                      if (value != null) {
                        setState(() {
                          sortType = value;
                        });
                      }
                    },
                  ),
                const Divider(),
                for (var item in SortDirection.values)
                  RadioListTile<SortDirection>(
                    title: Text(
                      '${item.name[0].toUpperCase()}${item.name.substring(1)}',
                    ),
                    value: item,
                    groupValue: sortDir,
                    onChanged: (SortDirection? value) {
                      if (value != null) {
                        setState(() {
                          sortDir = value;
                        });
                      }
                    },
                  ),
              ],
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(
                context,
                SortRule(sortType, sortDir),
              );
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}

/// Prompt the user for a new filename.
Future<String?> filenameDialog({
  required BuildContext context,
  String? initName,
  String title = 'New Filename',
  String? label,
}) async {
  final filenameEditKey = GlobalKey<FormFieldState>();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: filenameEditKey,
          decoration: InputDecoration(labelText: label ?? ''),
          autofocus: true,
          initialValue: initName ?? '',
          validator: (String? text) {
            if (text == null) return 'Cannot be empty';
            text = text.trim();
            if (text.isEmpty) return 'Cannot be empty';
            if (text.contains('/')) {
              return 'Cannot contain "/" characters';
            }
            if (Platform.isWindows && (text.contains('\\'))) {
              return 'Cannot contain "\\" characters';
            }
            if (text == initName) return 'A new name is required';
            return null;
          },
          onFieldSubmitted: (value) {
            // Complete the dialog when the user presses enter.
            if (filenameEditKey.currentState!.validate()) {
              Navigator.pop(
                  context, filenameEditKey.currentState!.value.trim());
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              if (filenameEditKey.currentState!.validate()) {
                Navigator.pop(
                    context, filenameEditKey.currentState!.value.trim());
              }
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}

/// Dialog to select file mode permissions.
Future<int?> modeSetDialog({
  required BuildContext context,
  required int initialMode,
}) async {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      var mode = initialMode;
      // The mask for each permission bit, in typical order.
      const masks = [0x100, 0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1];
      return AlertDialog(
        title: const Text('File Mode'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            //
            // Nested function for checkboxes with access to mode and setState.
            DataCell checkboxGen(int pos) {
              return DataCell(
                Checkbox(
                  // User read.
                  value: (mode & masks[pos]) != 0,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        mode = mode ^ masks[pos];
                      });
                    }
                  },
                ),
              );
            }

            return DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text(''), numeric: true),
                DataColumn(label: Text('  R  ')),
                DataColumn(label: Text('  W  ')),
                DataColumn(label: Text('  X  ')),
              ],
              rows: <DataRow>[
                DataRow(
                  cells: <DataCell>[
                    const DataCell(Text('user')),
                    for (var i = 0; i < 3; i++) checkboxGen(i),
                  ],
                ),
                DataRow(
                  cells: <DataCell>[
                    const DataCell(Text('group')),
                    for (var i = 3; i < 6; i++) checkboxGen(i),
                  ],
                ),
                DataRow(
                  cells: <DataCell>[
                    const DataCell(Text('other')),
                    for (var i = 6; i < 9; i++) checkboxGen(i),
                  ],
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(
                context,
                // Return the value if changed.
                mode != initialMode ? mode : null,
              );
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}

/// Prompt for a one-line text entry with OK and CANCEL buttons.
Future<String?> textDialog({
  required BuildContext context,
  String? initText,
  String title = 'Enter Text',
  String? label,
  bool allowEmpty = false,
  bool obscureText = false,
}) async {
  final textEditKey = GlobalKey<FormFieldState>();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: textEditKey,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
          obscureText: obscureText,
          initialValue: initText ?? '',
          validator: (String? text) {
            if (!allowEmpty && (text?.isEmpty ?? false)) {
              return 'Cannot be empty';
            }
            return null;
          },
          onFieldSubmitted: (value) {
            // Complete the dialog when the user presses enter.
            if (textEditKey.currentState!.validate()) {
              Navigator.pop(context, textEditKey.currentState!.value);
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              if (textEditKey.currentState!.validate()) {
                Navigator.pop(context, textEditKey.currentState!.value);
              }
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}

/// Show a standard about dialog.
Future<void> aboutDialog({
  required BuildContext context,
}) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'remoTree',
    applicationVersion: 'Version ${packageInfo.version}',
    applicationLegalese: '©2024 by Douglas W. Bell',
    applicationIcon: Image.asset('assets/images/remotree_icon_48.png'),
  );
}

/// Show a wait/progress indicator.
Future<void> waitDialog({
  required BuildContext context,
}) async {
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    },
  );
}
