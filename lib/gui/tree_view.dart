// tree_view.dart, the main view showing a file tree.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2025, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as common_dialogs;
import 'edit_view.dart';
import 'info_view.dart';
import '../main.dart' show prefs;
import '../model/file_interface.dart';
import '../model/file_item.dart';

/// The main tree view for remote and local file display.
///
/// Uses generics to select remote or local models.
class TreeView<T extends FileInterface> extends StatefulWidget {
  const TreeView({super.key});

  @override
  State<TreeView<T>> createState() => _TreeViewState<T>();
}

class _TreeViewState<T extends FileInterface> extends State<TreeView<T>> {
  final selectedItems = <FileItem>[];
  var hideDotFiles = prefs.getBool('hide_dot_files') ?? true;
  static final copyItems = <FileItem>[];
  static FileInterface? copyFromModel;

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      builder: (context, model, child) {
        if (model is RemoteInterface) {
          if ((model as RemoteInterface).isClientConnected) {
            // Connect if remote and not already done.
            (model as RemoteInterface).connectToSftp();
          } else {
            // Close view if no connection (goes back to HostSelect).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            });
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              selectedItems.isEmpty
                  ? copyItems.isEmpty
                      ? 'remoTree - ${model.currentConnectName}'
                      : 'remoTree - ${copyItems.length} to copy'
                  : copyItems.isEmpty
                      ? 'remoTree - ${selectedItems.length} selected'
                      : 'remoTree - ${selectedItems.length} selected / '
                          '${copyItems.length} to copy',
            ),
            leading: selectedItems.isEmpty && copyItems.isEmpty
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Open Drawer Menu',
                    onPressed: () {
                      // Open drawer from parent frame scaffold.
                      Scaffold.of(context).openDrawer();
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Clear Selection & Copy Buffer',
                    onPressed: () {
                      setState(() {
                        selectedItems.clear();
                        copyItems.clear();
                        copyFromModel = null;
                      });
                    },
                  ),
            actions: <Widget>[
              if (selectedItems.isNotEmpty && copyItems.isEmpty) ...[
                if (selectedItems.length == 1 &&
                    selectedItems.first.type == FileType.directory)
                  IconButton(
                    // New root command.
                    icon: const Icon(Icons.anchor),
                    tooltip: 'Set this a tree root',
                    onPressed: () {
                      final path = selectedItems.first.fullPath;
                      selectedItems.clear();
                      model.changeRootPath(path);
                    },
                  ),
                if (selectedItems.length == 1 &&
                    selectedItems.first.type == FileType.file)
                  IconButton(
                    // Edit command.
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit the Selected Item',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditView(
                            modelRef: model,
                            fileItem: selectedItems.first,
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  // Copy command.
                  icon: const Icon(Icons.copy),
                  tooltip: 'Mark Items for Copy',
                  onPressed: () {
                    setState(() {
                      copyItems.addAll(selectedItems);
                      copyFromModel = model;
                      selectedItems.clear();
                    });
                  },
                ),
                IconButton(
                  // Info command.
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Show Information for Items',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            InfoView<T>(fileItems: selectedItems),
                      ),
                    );
                  },
                ),
                IconButton(
                  // Delete command.
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete Selected Items',
                  onPressed: () async {
                    final doContinue = await common_dialogs.okCancelDialog(
                      context: context,
                      title: 'Confirm Delete',
                      label: 'Delete ${selectedItems.length} object?',
                    );
                    if (doContinue ?? false) {
                      final selItems = List.of(selectedItems);
                      selectedItems.clear();
                      model.deleteItems(selItems);
                    }
                  },
                ),
              ],
              if (selectedItems.length == 1 &&
                  copyItems.isNotEmpty &&
                  selectedItems.first.type == FileType.directory)
                IconButton(
                  // Paste command.
                  icon: const Icon(Icons.paste),
                  tooltip: 'Paste the Copied Items',
                  onPressed: () async {
                    final copyItemsTmp = List.of(copyItems);
                    final destination = selectedItems.first;
                    selectedItems.clear();
                    copyItems.clear();
                    common_dialogs.waitDialog(context: context);
                    await model.copyFileOperation(
                      copyFromModel!,
                      copyItemsTmp,
                      destination,
                    );
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                ),
              if (selectedItems.isEmpty && copyItems.isEmpty) ...[
                IconButton(
                  // Refresh command.
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Files',
                  onPressed: () {
                    model.refreshFiles();
                  },
                ),
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
                if (model is RemoteInterface)
                  IconButton(
                    // Close connection command.
                    icon: const Icon(Icons.logout),
                    tooltip: 'Close Connection',
                    onPressed: () {
                      model.closeConnection();
                      // Will be popped when rebuilt.
                    },
                  ),
              ],
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
                      final separator = model is RemoteInterface
                          ? '/'
                          : Platform.pathSeparator;
                      final pathList = model.splitRootPath();
                      if (index.isEven) {
                        return InputChip(
                          label: Text(pathList[index ~/ 2]),
                          onPressed: (() {
                            var newPath = '';
                            if (index > 0) {
                              newPath = pathList
                                  .getRange(1, index ~/ 2 + 1)
                                  .join(separator);
                            }
                            model.changeRootPath('$separator$newPath');
                          }),
                        );
                      } else {
                        // Plain text for separators and last current item.
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            index == 1
                                ? ' :  $separator '
                                : index == pathList.length * 2 - 3
                                    ? ' $separator ${pathList.last}'
                                    : ' $separator ',
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

  /// The list of indedted tree widgets.
  List<Widget> _treeWidgets(FileInterface model) {
    final treeWidgets = <Widget>[];
    for (var root in model.rootItems) {
      for (var item in openItemGenerator(
        root,
        hideDotFiles: hideDotFiles,
      )) {
        final isItemSelected = selectedItems.contains(item);
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
                  if (isItemSelected) {
                    selectedItems.remove(item);
                  } else {
                    selectedItems.add(item);
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
                    color: isItemSelected
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
                            color: isItemSelected
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
