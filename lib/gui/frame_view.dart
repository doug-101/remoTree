// frame_view.dart, the framework view toglling remote and local views.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'host_select.dart';
import 'tree_view.dart';
import '../model/file_interface.dart';
import '../model/file_item.dart';

class FrameView extends StatefulWidget {
  FrameView({super.key});

  @override
  State<FrameView> createState() => _FrameViewState();
}

class _FrameViewState extends State<FrameView> {
  var remoteShown = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: remoteShown ? 0 : 1,
        onDestinationSelected: (int index) {
          setState(() {
            remoteShown = index == 0;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.network_wifi_3_bar),
            label: 'Remote Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on),
            label: 'Local Files',
          ),
        ],
      ),
      body: IndexedStack(
        index: remoteShown ? 0 : 1,
        sizing: StackFit.passthrough,
        children: <Widget>[
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
          TreeView<LocalInterface>(),
        ],
      ),
    );
  }
}
