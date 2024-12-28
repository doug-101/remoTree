// edit_view.dart, a view for editing text files.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'common_dialogs.dart' as common_dialogs;
import '../model/file_interface.dart';
import '../model/file_item.dart';

/// The view for showing and editing text files.
class EditView extends StatefulWidget {
  final FileInterface modelRef;
  final FileItem fileItem;

  const EditView({super.key, required this.modelRef, required this.fileItem});

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  var isChanged = false;
  late TextEditingController _textController;
  final ScrollController _vertScrollController = ScrollController();
  final ScrollController _horizScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadText();
  }

  Future<void> _loadText() async {
    _textController.text =
        await widget.modelRef.readFileAsString(widget.fileItem);
    _textController.addListener(() {
      isChanged = true;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('remoTree - ${widget.fileItem.filename}'),
        actions: <Widget>[
          IconButton(
            // Save command.
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save the file to disk.',
            onPressed: () async {
              await widget.modelRef.writeFileAsString(
                widget.fileItem,
                _textController.text,
              );
              isChanged = false;
            },
          ),
          IconButton(
            // Revert command.
            icon: const Icon(Icons.restore),
            tooltip: 'Restore the file from the disk.',
            onPressed: () async {
              _textController.text =
                  await widget.modelRef.readFileAsString(widget.fileItem);
              isChanged = false;
            },
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) return;
          if (isChanged) {
            final closeOk = await common_dialogs.okCancelDialog(
              context: context,
              title: 'Confirm Discard',
              label: 'Discard changes?',
            );
            if (closeOk ?? false) {
              isChanged = false;
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          } else {
            Navigator.pop(context);
          }
        },
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
                builder:
                    (BuildContext context, BoxConstraints viewportConstraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizScrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: viewportConstraints.maxWidth,
                        minHeight: viewportConstraints.maxHeight,
                      ),
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: _textController,
                          scrollController: _vertScrollController,
                          maxLines: null,
                          decoration: null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
