// file_choice.dart, a view for selecting local files.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2025, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as common_dialogs;
import '../model/file_interface.dart';
import '../model/file_item.dart';

/// A tree-based view for local file selection.
class FileChoice extends StatefulWidget {
  final String? title;
  final bool selectFilesOnly;

  const FileChoice({super.key, this.title, this.selectFilesOnly = true});

  @override
  State<FileChoice> createState() => _FileChoiceState();
}

class _FileChoiceState extends State<FileChoice> {
  FileItem? selectedItem;
  var hideDotFiles = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalInterface>(
      builder: (context, model, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title ?? 'Select a file'),
            leading: selectedItem != null
                ? IconButton(
                    icon: const Icon(Icons.check_circle),
                    tooltip: 'Complete the selection',
                    onPressed: () {
                      Navigator.pop(context, selectedItem);
                    },
                  )
                // Take up space when check button is hidden.
                : const SizedBox(width: 24.0),
            actions: <Widget>[
              IconButton(
                // Show hidden files.
                icon: Icon(hideDotFiles
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                tooltip: 'Toggle Show Hidden Files',
                onPressed: () {
                  setState(() {
                    hideDotFiles = !hideDotFiles;
                  });
                },
              ),
              IconButton(
                // Sort rule command.
                icon: const Icon(Icons.sort),
                tooltip: 'Change Sort Rule',
                onPressed: () async {
                  final newSortRule = await common_dialogs.sortRuleDialog(
                    context: context,
                    initialRule: model.sortRule,
                  );
                  if (newSortRule != null) {
                    model.changeSortRule(newSortRule);
                  }
                },
              ),
              IconButton(
                // Cancel selection command.
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: () {
                  Navigator.pop(context, null);
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(10),
            // The breadcrumb navigation area.
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: model.splitRootPath().isNotEmpty
                        ? model.splitRootPath().length * 2 - 2
                        : 0,
                    itemBuilder: (BuildContext context, int index) {
                      final pathList = model.splitRootPath();
                      if (index.isEven) {
                        return InputChip(
                          label: Text(pathList[index ~/ 2]),
                          onPressed: (() {
                            var newPath = '';
                            if (index > 0) {
                              newPath = pathList
                                  .getRange(1, index ~/ 2 + 1)
                                  .join(Platform.pathSeparator);
                            }
                            model.changeRootPath('${Platform.pathSeparator}$newPath');
                          }),
                        );
                      } else {
                        // Plain text for separators and last current item.
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            index == 1
                                ? ' :  ${Platform.pathSeparator} '
                                : index == pathList.length * 2 - 3
                                    ? ' ${Platform.pathSeparator} ${pathList.last}'
                                    : ' ${Platform.pathSeparator} ',
                          ),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: _treeWidgets(model),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The list of indented tree widgets.
  List<Widget> _treeWidgets(FileInterface model) {
    final treeWidgets = <Widget>[];
    for (var root in model.rootItems) {
      for (var item in openItemGenerator(
        root,
        hideDotFiles: hideDotFiles,
      )) {
        final dateString = DateTime.now().difference(item.modTime).inDays < 183
            ? DateFormat('MMM dd HH:mm').format(item.modTime)
            : DateFormat('MMM dd  yyyy').format(item.modTime);
        final sizeString =
            item.fileSize != null ? ', ${item.fileSizeString}' : '';
        treeWidgets.add(
          Padding(
            padding:
                EdgeInsets.fromLTRB(30.0 * item.level + 4.0, 8.0, 4.0, 8.0),
            child: GestureDetector(
              onTap: () {
                model.toggleItemOpen(item);
              },
              onLongPress: () {
                setState(() {
                  if (!widget.selectFilesOnly || item.type == FileType.file) {
                    selectedItem = selectedItem != item ? item : null;
                  }
                });
              },
              child: Row(
                children: <Widget>[
                  Icon(
                    switch (item.type) {
                      FileType.directory =>
                        item.isOpen ? Icons.folder_open : Icons.folder_outlined,
                      FileType.file => Icons.insert_drive_file_outlined,
                      FileType.link => Icons.link,
                      _ => Icons.question_mark,
                    },
                    color: selectedItem == item
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text.rich(
                        TextSpan(
                          text: item.filename,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            color: selectedItem == item
                                ? Theme.of(context).colorScheme.secondary
                                : null,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: '\n$dateString$sizeString',
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return treeWidgets;
  }
}
