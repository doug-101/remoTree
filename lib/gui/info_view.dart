// info_view.dart, a view showing details about file objects.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import '../model/file_interface.dart';
import '../model/file_item.dart';

/// Shows and allows editing of file object details.
class InfoView<T extends FileInterface> extends StatelessWidget {
  final List<FileItem> fileItems;

  InfoView({super.key, required this.fileItems});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('remoTree - Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 600.0,
            child: Consumer<T>(
              builder: (context, model, child) {
                return ListView(
                  children: <Widget>[
                    for (var item in fileItems)
                      Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                switch (item.type) {
                                  FileType.directory => Icons.folder_open,
                                  FileType.file =>
                                    Icons.insert_drive_file_outlined,
                                  FileType.link => Icons.link,
                                  _ => Icons.question_mark,
                                },
                              ),
                              DataTable(
                                dividerThickness: 0.001,
                                columns: <DataColumn>[
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Name:'),
                                  ),
                                  DataColumn(
                                    label: InkWell(
                                      child: Text(
                                        item.filename,
                                        style: TextStyle(
                                          fontFamily: 'RobotoMono',
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      onTap: () async {
                                        final newName =
                                            await commonDialogs.filenameDialog(
                                          context: context,
                                          initName: item.filename,
                                        );
                                        if (newName != null) {
                                          model.renameItem(item, newName);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                                rows: <DataRow>[
                                  DataRow(
                                    cells: <DataCell>[
                                      DataCell(Text('Modified:')),
                                      DataCell(
                                        Text(
                                          DateFormat('MMM dd yyyy, HH:mm')
                                              .format(item.modTime),
                                          style: TextStyle(
                                            fontFamily: 'RobotoMono',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.accessTime != null)
                                    DataRow(
                                      cells: <DataCell>[
                                        DataCell(Text('Accessed:')),
                                        DataCell(
                                          Text(
                                            DateFormat('MMM dd yyyy, HH:mm')
                                                .format(item.accessTime!),
                                            style: TextStyle(
                                              fontFamily: 'RobotoMono',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (item.fileSize != null)
                                    DataRow(
                                      cells: <DataCell>[
                                        DataCell(Text('Size:')),
                                        DataCell(Text(
                                          item.fileSizeString,
                                          style: TextStyle(
                                            fontFamily: 'RobotoMono',
                                          ),
                                        )),
                                      ],
                                    ),
                                  if (item.mode != null)
                                    DataRow(
                                      cells: <DataCell>[
                                        DataCell(Text('File Mode:')),
                                        DataCell(
                                          model is RemoteInterface
                                              ? InkWell(
                                                  child: Text(
                                                    item.fileModeString,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                      fontFamily: 'RobotoMono',
                                                    ),
                                                  ),
                                                  onTap: () async {
                                                    final newMode =
                                                        await commonDialogs
                                                            .modeSetDialog(
                                                      context: context,
                                                      initialMode: item.mode!,
                                                    );
                                                    if (newMode != null) {
                                                      model.changeItemMode(
                                                        item,
                                                        newMode,
                                                      );
                                                    }
                                                  },
                                                )
                                              : Text(
                                                  item.fileModeString,
                                                  style: TextStyle(
                                                    fontFamily: 'RobotoMono',
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
