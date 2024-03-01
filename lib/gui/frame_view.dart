// frame_view.dart, the framework view toggling remote and local views.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'help_view.dart';
import 'host_select.dart';
import 'settings_edit.dart';
import 'shell_view.dart';
import 'tree_view.dart';
import '../main.dart' show prefs, saveWindowGeo;
import '../model/file_interface.dart';
import '../model/file_item.dart';

enum ViewType { localFiles, remoteFiles, terminal }

/// The framework view that shows a bottom nav bar.
class FrameView extends StatefulWidget {
  FrameView({super.key});

  @override
  State<FrameView> createState() => _FrameViewState();
}

class _FrameViewState extends State<FrameView> with WindowListener {
  var _tabShown = ViewType.remoteFiles;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Call main function to save window geometry after a resize.
  @override
  void onWindowResize() async {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await saveWindowGeo();
    }
  }

  /// Call main function to save window geometry after a move.
  @override
  void onWindowMove() async {
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await saveWindowGeo();
    }
  }

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
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingEdit(),
                  ),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help View'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HelpView(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About remoTree'),
              onTap: () {
                Navigator.pop(context);
                commonDialogs.aboutDialog(context: context);
              },
            ),
            if (defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.macOS) ...[
              Divider(),
              ListTile(
                leading: const Icon(Icons.highlight_off_outlined),
                title: const Text('Quit'),
                onTap: () {
                  SystemNavigator.pop();
                },
              ),
            ],
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
          // A nested navigator to manage views for the local tab view.
          Navigator(
            onGenerateRoute: (RouteSettings settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) {
                  return TreeView<LocalInterface>();
                },
              );
            },
          ),
          // A nested navigator to manage views for the remote tab view.
          Navigator(
            onGenerateRoute: (RouteSettings settings) {
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) {
                  final model =
                      Provider.of<RemoteInterface>(context, listen: false);
                  switch (settings.name) {
                    case '/':
                      if (model.isConnected) {
                        return TreeView<RemoteInterface>();
                      } else {
                        return HostSelect();
                      }
                    case '/remote':
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
              final model =
                  Provider.of<RemoteInterface>(context, listen: false);
              return MaterialPageRoute(
                settings: settings,
                builder: (BuildContext context) {
                  switch (settings.name) {
                    case '/':
                      if (model.isConnected) {
                        return ShellView();
                      } else {
                        return HostSelect();
                      }
                    case '/remote':
                      return ShellView();
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
