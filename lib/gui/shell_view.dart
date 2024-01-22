// shell_view.dart, a view for use as a ssh shell.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
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
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteInterface>(
      builder: (context, model, child) {
        if (model.isConnected) {
          // Add SSH start here.
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
          body: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Flexible(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  onEditingComplete: () async {
                    model.sendToShell(_textController.text);
                    _textController.text = '';
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
