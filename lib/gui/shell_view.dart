// shell_view.dart, a view for use as a ssh shell.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import '../model/file_interface.dart';
import '../model/file_item.dart';

// The view for interacting with the shell.
class ShellView extends StatefulWidget {
  final String? initPath;

  ShellView({super.key, this.initPath});

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  var widthPerChar = 0.0;
  var maxCharPerLine = 100;
  final ScrollController _vertScrollController = ScrollController();
  final ScrollController _horizScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteInterface>(
      builder: (context, model, child) {
        if (model.isConnected) {
          model.connectToShell();
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
            title: Text('remoTree - Terminal'),
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
                  final _char = event.character;
                  if (_char != null) {
                    model.sendToShell(_char);
                  } else {
                    final escStr = String.fromCharCode(0x1b);
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
                    }
                  }
                }
                return KeyEventResult.handled;
              },
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
                          if (widthPerChar == 0.0) {
                            // Calculate width of a wide char for view width.
                            final painter = TextPainter(
                              text: TextSpan(
                                text: 'WWWWWWWWWW',
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                ),
                              ),
                              textDirection: TextDirection.ltr,
                            );
                            painter.layout();
                            widthPerChar = painter.width / 10;
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_vertScrollController.hasClients) {
                              _vertScrollController.jumpTo(0.0);
                            }
                          });
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _horizScrollController,
                            child: SizedBox(
                              width: max(
                                widthPerChar * maxCharPerLine + 10.0,
                                viewportConstraints.maxWidth,
                              ),
                              child: ListView.builder(
                                controller: _vertScrollController,
                                itemCount: model.outputLines.length,
                                itemExtent: 30.0,
                                shrinkWrap: true,
                                reverse: true,
                                // Scrolling and filling in reverse is more
                                // reliable for scroll to the bottom.
                                itemBuilder: (BuildContext context, int index) {
                                  return Text(
                                    model.outputLines[
                                        model.outputLines.length - index - 1],
                                    style: TextStyle(
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
          ),
        );
      },
    );
  }
}
