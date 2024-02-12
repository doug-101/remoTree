// host_select.dart, a view showing available remote servers.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'host_edit.dart';
import '../model/file_interface.dart';
import '../model/host_list.dart';

enum MenuItems { edit, delete }

/// Shows and allows selection of available hosts.
class HostSelect extends StatelessWidget {
  HostSelect({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('remoTree - Remote'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open Drawer Menu',
          onPressed: () {
            // Open drawer from parent frame scaffold.
            Scaffold.of(context).openDrawer();
          },
        ),
        actions: <Widget>[
          IconButton(
            // New host command.
            icon: const Icon(Icons.add_box),
            tooltip: 'New host',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HostEdit(),
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
            child: Consumer<HostList>(
              builder: (context, model, child) {
                return ListView(
                  children: <Widget>[
                    for (var data in model.sortedHostData)
                      Card(
                        child: ListTile(
                          title: Text(data.displayName),
                          subtitle: Text(
                            data.nameAndAddress,
                            style: TextStyle(
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                          trailing: PopupMenuButton<MenuItems>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (MenuItems result) async {
                              switch (result) {
                                case MenuItems.edit:
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HostEdit(
                                        origHostData: data,
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
                                    model.deleteHostData(data);
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
                            final interfaceModel = Provider.of<RemoteInterface>(
                              context,
                              listen: false,
                            );
                            await interfaceModel.connectToClient(
                              hostData: data,
                              passwordFunction: () async {
                                return commonDialogs.textDialog(
                                  context: context,
                                  title: 'Enter password',
                                  obscureText: true,
                                );
                              },
                              keyPassphraseFunction: () async {
                                return commonDialogs.textDialog(
                                  context: context,
                                  title: 'Enter key passphrase',
                                  obscureText: true,
                                );
                              },
                            );
                            Navigator.pushNamed(
                              context,
                              '/remote',
                            );
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
