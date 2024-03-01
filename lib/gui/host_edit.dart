// host_edit.dart, a view to edit connection data.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart';
import 'file_choice.dart';
import '../model/file_interface.dart';
import '../model/file_item.dart';
import '../model/host_list.dart';
import '../model/host_data.dart';

/// A class for editibng and new host connection data.
class HostEdit extends StatefulWidget {
  HostData? origHostData;

  HostEdit({super.key, this.origHostData});

  @override
  State<HostEdit> createState() => _HostEditState();
}

class _HostEditState extends State<HostEdit> {
  final _formKey = GlobalKey<FormState>();
  bool _cancelFlag = false;
  late final HostData newHostData;

  @override
  void initState() {
    super.initState();
    if (widget.origHostData != null) {
      newHostData = HostData.copy(widget.origHostData!);
    } else {
      newHostData = HostData('', '', '');
    }
  }

  /// Save the host data at exit if applicable.
  Future<bool> updateOnPop() async {
    if (_cancelFlag) return true;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final model = Provider.of<HostList>(context, listen: false);
      if (widget.origHostData != null) {
        model.replaceHostData(widget.origHostData!, newHostData);
      } else {
        model.addHostData(newHostData);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.origHostData != null ? 'Edit Host Data' : 'New Host Data'),
        leading: IconButton(
          icon: const Icon(Icons.check_circle),
          tooltip: 'Save the host data',
          onPressed: () async {
            if (await updateOnPop()) {
              Navigator.pop(context, null);
            }
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel changes',
            onPressed: () {
              _cancelFlag = true;
              Navigator.pop(context, null);
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        onWillPop: updateOnPop,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: SizedBox(
              width: 350.0,
              child: ListView(
                children: <Widget>[
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Display Name'),
                    autofocus: true,
                    initialValue: widget.origHostData?.displayName,
                    validator: (String? text) {
                      if (text != null && text.isEmpty) {
                        return 'Cannot be empty';
                      }
                      return null;
                    },
                    onSaved: (String? text) {
                      if (text != null) {
                        newHostData.displayName = text;
                      }
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'User Name'),
                    initialValue: widget.origHostData?.userName,
                    validator: (String? text) {
                      if (text != null && text.isEmpty) {
                        return 'Cannot be empty';
                      }
                      return null;
                    },
                    onSaved: (String? text) {
                      if (text != null) {
                        newHostData.userName = text;
                      }
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Address'),
                    autofocus: true,
                    initialValue: widget.origHostData?.address,
                    validator: (String? text) {
                      if (text != null && text.isEmpty) {
                        return 'Cannot be empty';
                      }
                      return null;
                    },
                    onSaved: (String? text) {
                      if (text != null) {
                        newHostData.address = text;
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton(
                      child: Text(
                        newHostData.key != null
                            ? 'Remove Private Key'
                            : 'Add Private Key',
                      ),
                      onPressed: () async {
                        if (newHostData.key != null) {
                          // Remove the existing key.
                          setState(() {
                            newHostData.key = null;
                          });
                        } else {
                          // Add a new key.
                          final method = await choiceDialog(
                            context: context,
                            choices: [
                              'Create on server',
                              'Load from file',
                            ],
                            title: 'Add Key',
                          );
                          if (method != null) {
                            final interfaceModel = Provider.of<RemoteInterface>(
                              context,
                              listen: false,
                            );
                            if (method == 'Create on server') {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                              }
                              await interfaceModel.connectToClient(
                                hostData: newHostData,
                                passwordFunction: () async {
                                  return textDialog(
                                    context: context,
                                    title: 'Enter server password',
                                    obscureText: true,
                                  );
                                },
                              );
                              String? passphrase;
                              String? passphraseMatch;
                              do {
                                passphrase = await textDialog(
                                  context: context,
                                  title: 'Passphrase',
                                  label: '(empty for none)',
                                  allowEmpty: true,
                                  obscureText: true,
                                );
                                if (passphrase == null) {
                                  interfaceModel.closeConnection();
                                  return;
                                }
                                if (passphrase.isEmpty) {
                                  passphraseMatch = '';
                                } else {
                                  passphraseMatch = await textDialog(
                                    context: context,
                                    title: 'Passphrase Match',
                                    label: 'Enter matching passphrase',
                                    obscureText: true,
                                  );
                                  if (passphraseMatch == null) {
                                    interfaceModel.closeConnection();
                                    return;
                                  }
                                }
                              } while (passphrase != passphraseMatch);
                              await interfaceModel.createServerKey(
                                newHostData,
                                passphrase,
                              );
                              interfaceModel.closeConnection();
                              setState(() {});
                            } else {
                              // Load from a file.
                              final localModel = Provider.of<LocalInterface>(
                                context,
                                listen: false,
                              );
                              await localModel.refreshFiles();
                              final FileItem? fileItem = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return FileChoice(
                                      title: 'Select key file',
                                    );
                                  },
                                ),
                              );
                              if (fileItem != null) {
                                final keyString =
                                    await localModel.readFileAsString(fileItem);
                                interfaceModel.addStringKey(
                                  newHostData,
                                  keyString,
                                );
                                setState(() {});
                              }
                            }
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
