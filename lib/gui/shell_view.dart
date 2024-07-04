// shell_view.dart, a view for use as a ssh shell.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../model/file_interface.dart';
import '../main.dart' show prefs;

// The view for interacting with the shell.
class ShellView extends StatefulWidget {
  final String? initPath;

  const ShellView({super.key, this.initPath});

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  var _widthPerChar = 0.0;
  var _shellWasClosed = false;
  final ScrollController _vertScrollController = ScrollController();
  final ScrollController _horizScrollController = ScrollController();
  static final escStr = String.fromCharCode(0x1b);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Connect to shell, then cleanup when it completes.
  Future<void> makeShellConnection(RemoteInterface modelRef) async {
    await modelRef.connectToShell();
    _shellWasClosed = true;
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteInterface>(
      builder: (context, model, child) {
        if (model.isClientConnected) {
          if (!model.isShellConnected && !_shellWasClosed) {
            makeShellConnection(model);
          }
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('remoTree - Terminal'),
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
                // Close connection command.
                icon: const Icon(Icons.logout),
                tooltip: 'Close Connection',
                onPressed: () {
                  model.closeConnection();
                  // Will be popped when rebuilt.
                },
              ),
            ],
          ),
          body: GestureDetector(
            onTap: () {
              if (Platform.isAndroid || Platform.isIOS) {
                setState(() {
                  SystemChannels.textInput.invokeMethod('TextInput.show');
                });
              }
            },
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  final char = event.character;
                  if (char != null) {
                    model.sendToShell(char);
                  } else {
                    switch (event.logicalKey) {
                      case LogicalKeyboardKey.arrowUp:
                        model.sendToShell('$escStr[A');
                      case LogicalKeyboardKey.arrowDown:
                        model.sendToShell('$escStr[B');
                      case LogicalKeyboardKey.arrowRight:
                        model.sendToShell('$escStr[C');
                      case LogicalKeyboardKey.arrowLeft:
                        model.sendToShell('$escStr[D');
                      case LogicalKeyboardKey.home:
                        model.sendToShell('$escStr[H');
                      case LogicalKeyboardKey.end:
                        model.sendToShell('$escStr[F');
                      case LogicalKeyboardKey.backspace:
                        // Linux sends Ctrl-H as char above, but
                        // Android needs this entry.
                        model.sendToShell(String.fromCharCode(8));
                    }
                  }
                }
                return KeyEventResult.handled;
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Scrollbar(
                        controller: _vertScrollController,
                        notificationPredicate: (notif) => notif.depth == 1,
                        thumbVisibility: true,
                        child: Scrollbar(
                          controller: _horizScrollController,
                          thumbVisibility: true,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: LayoutBuilder(
                              builder: (BuildContext context,
                                  BoxConstraints viewportConstraints) {
                                if (_widthPerChar == 0.0) {
                                  // Calculate wide char width for view width.
                                  final painter = TextPainter(
                                    text: const TextSpan(
                                      text: 'WWWWWWWWWW',
                                      style: TextStyle(
                                        fontFamily: 'RobotoMono',
                                      ),
                                    ),
                                    textDirection: TextDirection.ltr,
                                  );
                                  painter.layout();
                                  _widthPerChar = painter.width / 10;
                                }
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (_vertScrollController.hasClients) {
                                    _vertScrollController.jumpTo(0.0);
                                  }
                                });
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: _horizScrollController,
                                  child: SizedBox(
                                    width: max(
                                      _widthPerChar *
                                              RemoteInterface.maxLineLength +
                                          40.0,
                                      viewportConstraints.maxWidth,
                                    ),
                                    child: ListView.builder(
                                      controller: _vertScrollController,
                                      itemCount: model.outputLines.length,
                                      itemExtent: 30.0,
                                      shrinkWrap: true,
                                      reverse: true,
                                      // Scrolling and filling in reverse is
                                      // more reliable for scroll to the bottom.
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return Text(
                                          model.outputLines[
                                              model.outputLines.length -
                                                  index -
                                                  1],
                                          style: const TextStyle(
                                            fontFamily: 'RobotoMono',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_shellWasClosed)
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ElevatedButton(
                          onPressed: () {
                            _shellWasClosed = false;
                            model.updateViews();
                          },
                          child: const Text('Reconnect'),
                        ),
                      ),
                    ),
                  if (prefs.getBool('show_extra_keys') ??
                      (defaultTargetPlatform == TargetPlatform.android ||
                          defaultTargetPlatform == TargetPlatform.iOS))
                    Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: <Widget>[
                        ActionChip(
                          // A left arrow.
                          label: const Text('\u2190'),
                          onPressed: () {
                            model.sendToShell('$escStr[D');
                          },
                        ),
                        ActionChip(
                          // A down arrow.
                          label: const Text('\u2193'),
                          onPressed: () {
                            model.sendToShell('$escStr[B');
                          },
                        ),
                        ActionChip(
                          // An up arrow.
                          label: const Text('\u2191'),
                          onPressed: () {
                            model.sendToShell('$escStr[A');
                          },
                        ),
                        ActionChip(
                          // A right arrow.
                          label: const Text('\u2192'),
                          onPressed: () {
                            model.sendToShell('$escStr[C');
                          },
                        ),
                        ActionChip(
                          // A home key.
                          label: const Text('\u219e'),
                          onPressed: () {
                            model.sendToShell('$escStr[H');
                          },
                        ),
                        ActionChip(
                          // An end key.
                          label: const Text('\u21a0'),
                          onPressed: () {
                            model.sendToShell('$escStr[F');
                          },
                        ),
                        ActionChip(
                          // A tab key.
                          label: const Text('\u21e5'),
                          onPressed: () {
                            model.sendToShell('\t');
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
