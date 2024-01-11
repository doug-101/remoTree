// frame_view.dart, the framework view toggling remote and local views.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'host_select.dart';
import 'tree_view.dart';
import '../model/file_interface.dart';
import '../model/file_item.dart';

enum ViewType { localFiles, remoteFiles, terminal }

/// The framework view that shows a bottom nav bar.
class FrameView extends StatefulWidget {
  FrameView({super.key});

  @override
  State<FrameView> createState() => _FrameViewState();
}

class _FrameViewState extends State<FrameView> {
  var _tabShown = ViewType.remoteFiles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary,
              ),
              child: Text(
                'remoTree',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiary,
                  fontSize: 36,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About TreeTag'),
              onTap: () {
                Navigator.pop(context);
                commonDialogs.aboutDialog(context: context);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabShown.index,
        onDestinationSelected: (int index) {
          setState(() {
            _tabShown = ViewType.values[index];
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.location_on),
            label: 'Local Files',
          ),
          NavigationDestination(
            icon: const Icon(Icons.network_wifi_3_bar),
            label: 'Remote Files',
          ),
          NavigationDestination(
            icon: const Icon(Icons.terminal),
            label: 'Remote Terminal',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabShown.index,
        sizing: StackFit.passthrough,
        children: <Widget>[
          TreeView<LocalInterface>(),
          // A nested navigator to manage views for the remote tab view.
          Navigator(
            onGenerateRoute: (RouteSettings settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) {
                  switch (settings.name) {
                    case '/':
                      return HostSelect();
                    case '/rem_tree':
                      return TreeView<RemoteInterface>();
                    default:
                      return HostSelect();
                  }
                },
              );
            },
          ),
          // A nested navigator to manage views for the terminal view.
          Navigator(
            onGenerateRoute: (RouteSettings settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) {
                  switch (settings.name) {
                    case '/':
                      return HostSelect();
                    case '/rem_tree':
                      return TreeView<RemoteInterface>();
                    default:
                      return HostSelect();
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
