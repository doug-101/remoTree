// main.dart, the main app entry point file.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gui/common_dialogs.dart' as coomonDialogs;
import 'gui/frame_view.dart';
import 'model/file_interface.dart';
import 'model/host_list.dart';
import 'model/theme_model.dart';

/// [prefs] is the global shared_preferences instance.
late final SharedPreferences prefs;

Future<void> main(List<String> cmdLineArgs) async {
  LicenseRegistry.addLicense(
    () => Stream<LicenseEntry>.value(
      const LicenseEntryWithLineBreaks(
        <String>['remoTree'],
        'RemoTree, Copyright (C) 2023 by Douglas W. Bell\n\n'
        'This program is free software; you can redistribute it and/or modify '
        'it under the terms of the GNU General Public License as published by '
        'the Free Software Foundation; either version 2 of the License, or '
        '(at your option) any later version.\n\n'
        'This program is distributed in the hope that it will be useful, but '
        'WITHOUT ANY WARRANTY; without even the implied warranty of '
        'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU '
        'General Public License for more details.\n\n'
        'You should have received a copy of the GNU General Public License '
        'along with this program; if not, write to the Free Software '
        'Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  '
        '02110-1301, USA.',
      ),
    ),
  );
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();

  // Use a global navigator key to get a BuildContext for an error dialog.
  final navigatorKey = GlobalKey<NavigatorState>();
  // Handle async exceptions.
  PlatformDispatcher.instance.onError = (error, stack) {
    var remoteDisconnectFlag = false;
    String? description;
    switch (error) {
      case final SocketException e:
        // For host not found, etc.
        description = e.message;
        remoteDisconnectFlag = true;
      case final SSHAuthError e:
        description = e.message;
        remoteDisconnectFlag = true;
      case final SSHKeyDecodeError e:
        description = e.message;
      case final SftpStatusError e:
        description = e.message;
      case final PathAccessException e:
        description = e.message;
      default:
        return false;
    }
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) {
          if (remoteDisconnectFlag) {
            final remoteModel =
                Provider.of<RemoteInterface>(context, listen: false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              remoteModel.closeConnection();
            });
          }
          return AlertDialog(
            title: Text('Error'),
            content: Text(description!),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HostList>(
          create: (_) => HostList(),
        ),
        ChangeNotifierProvider<RemoteInterface>(
          create: (_) => RemoteInterface(),
        ),
        ChangeNotifierProvider<LocalInterface>(
          create: (_) => LocalInterface(),
        ),
        ChangeNotifierProvider<ThemeModel>(
          create: (_) => ThemeModel(),
        ),
      ],
      child: Consumer<ThemeModel>(
        builder: (context, themeModel, child) {
          return MaterialApp(
            title: 'remoTree',
            theme: themeModel.getTheme(),
            home: FrameView(),
            // Pass key for error handling context.
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    ),
  );
}
