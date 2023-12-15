// tree_view.dart, the main view showing a file tree.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import '../main.dart' show prefs;
import '../model/connection.dart';
import '../model/file_item.dart';

class TreeView extends StatefulWidget {
  TreeView({super.key});

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  final selectedItems = <FileItem>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('remoTree'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Consumer<Connection>(
          builder: (context, model, child) {
            final pathWidgets = <Widget>[
              InputChip(
                label: Text(model.currentConnectName!),
                onPressed: (() {}),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(' : '),
              ),
            ];
            final parts = model.rootPath!.split('/');
            parts.removeAt(0);
            var incrPath = '';
            for (var part in parts) {
              incrPath = '$incrPath/$part';
              pathWidgets.addAll(
                [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(' / '),
                  ),
                  InputChip(
                    label: Text(part),
                    onPressed: (() {}),
                  ),
                ],
              );
            }
            final treeWidgets = <Widget>[];
            for (var root in model.rootItems) {
              for (var item in itemGenerator(
                root,
                showDotFiles: prefs.getBool('show_dot_files') ?? false,
              )) {
                final isItemSelected = selectedItems.contains(item);
                treeWidgets.add(
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        30.0 * item.level + 4.0, 8.0, 4.0, 8.0),
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
                              SftpFileType.directory => item.isOpen
                                  ? Icons.folder_open
                                  : Icons.folder_outlined,
                              SftpFileType.regularFile =>
                                Icons.insert_drive_file_outlined,
                              SftpFileType.symbolicLink => Icons.link,
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
            return PopScope(
              onPopInvoked: (bool didPop) {
                model.closeConnection();
              },
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: model.splitRootPath().length * 2 - 2,
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
                      children: treeWidgets,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
