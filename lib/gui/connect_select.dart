// connect_select.dart, a view showing available servers.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'connect_edit.dart';
import 'tree_view.dart';
import '../model/connection.dart';

enum MenuItems { edit, delete }

class ConnectSelect extends StatelessWidget {
  ConnectSelect({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('remoTree'),
        actions: <Widget>[
          IconButton(
            // New connection command.
            icon: const Icon(Icons.add_box),
            tooltip: 'New connection',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConnectEdit(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: SizedBox(
            width: 600.0,
            child: Consumer<Connection>(
              builder: (context, model, child) {
                return ListView(
                  children: <Widget>[
                    for (var data in model.sortedConnectData)
                      Card(
                        child: ListTile(
                          title: Text(data.displayName),
                          subtitle: Text(data.nameAndAddress),
                          trailing: PopupMenuButton<MenuItems>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (MenuItems result) async {
                              switch (result) {
                                case MenuItems.edit:
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ConnectEdit(
                                        origConnectData: data,
                                      ),
                                    ),
                                  );
                                case MenuItems.delete:
                                  final deleteOk =
                                      await commonDialogs.okCancelDialog(
                                    context: context,
                                    title: 'Confirm Delete',
                                    label: 'Delete this entry?',
                                  );
                                  if (deleteOk ?? false) {
                                    model.deleteConnectData(data);
                                  }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<MenuItems>(
                                child: Text('Edit entry'),
                                value: MenuItems.edit,
                              ),
                              PopupMenuItem<MenuItems>(
                                child: Text('Delete entry'),
                                value: MenuItems.delete,
                              ),
                            ],
                          ),
                          onTap: () async {
                            await model.connectToClient(
                              connectData: data,
                              passwordFunction: () async {
                                return commonDialogs.textDialog(
                                  context: context,
                                  title: 'Enter password',
                                  obscureText: true,
                                );
                              },
                            );
                            Navigator.pushNamed(context, '/treeView');
                          },
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
