// tree_view.dart, the main view showing a file tree.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import '../main.dart' show prefs;
import '../model/file_interface.dart';
import '../model/file_item.dart';

class TreeView<T extends FileInterface> extends StatefulWidget {
  TreeView({super.key});

  @override
  State<TreeView<T>> createState() => _TreeViewState<T>();
}

class _TreeViewState<T extends FileInterface> extends State<TreeView<T>> {
  final selectedItems = <FileItem>[];

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      builder: (context, model, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('remoTree - ${model.currentConnectName}'),
            actions: <Widget>[
              if (model is RemoteInterface)
                IconButton(
                  // Close connection command.
                  icon: const Icon(Icons.logout),
                  tooltip: 'Close Connection',
                  onPressed: () {
                    model.closeConnection();
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(10),
            child: PopScope(
              onPopInvoked: (bool didPop) {
                model.closeConnection();
              },
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
                                    .join('/');
                              }
                              model.changeRootPath('/$newPath');
                            }),
                          );
                        } else {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              index == 1
                                  ? ' :  / '
                                  : index == pathList.length * 2 - 3
                                      ? ' / ${pathList.last}'
                                      : ' / ',
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
          ),
        );
      },
    );
  }

  List<Widget> _treeWidgets(FileInterface model) {
    final treeWidgets = <Widget>[];
    for (var root in model.rootItems) {
      for (var item in itemGenerator(
        root,
        showDotFiles: prefs.getBool('show_dot_files') ?? false,
      )) {
        final isItemSelected = selectedItems.contains(item);
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
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        item.filename,
                        style: TextStyle(
                          color: isItemSelected
                              ? Theme.of(context).colorScheme.secondary
                              : null,
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
