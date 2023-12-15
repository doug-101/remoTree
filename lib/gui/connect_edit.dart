// connect_edit.dart, a view to edit connection data.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/connect_data.dart';
import '../model/connection.dart';

class ConnectEdit extends StatefulWidget {
  ConnectData? origConnectData;

  ConnectEdit({super.key, this.origConnectData});

  @override
  State<ConnectEdit> createState() => _ConnectEditState();
}

class _ConnectEditState extends State<ConnectEdit> {
  final _formKey = GlobalKey<FormState>();
  bool _cancelFlag = false;
  ConnectData? newConnectData;

  @override
  void initState() {
    super.initState();
    if (widget.origConnectData != null) {
      newConnectData = ConnectData.copy(widget.origConnectData!);
    } else {
      newConnectData = ConnectData('', '', '');
    }
  }

  Future<bool> updateOnPop() async {
    if (_cancelFlag) return true;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final model = Provider.of<Connection>(context, listen: false);
      if (widget.origConnectData != null) {
        model.replaceConnectData(widget.origConnectData!, newConnectData!);
      } else {
        model.addConnectData(newConnectData!);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.origConnectData != null
            ? 'Edit Connection Data'
            : 'New Connection Data'),
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
                    initialValue: widget.origConnectData?.displayName,
                    validator: (String? text) {
                      if (text != null && text.isEmpty) {
                        return 'Cannot be empty';
                      }
                      return null;
                    },
                    onSaved: (String? text) {
                      if (text != null) {
                        newConnectData!.displayName = text;
                      }
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'User Name'),
                    initialValue: widget.origConnectData?.userName,
                    validator: (String? text) {
                      if (text != null && text.isEmpty) {
                        return 'Cannot be empty';
                      }
                      return null;
                    },
                    onSaved: (String? text) {
                      if (text != null) {
                        newConnectData!.userName = text;
                      }
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Address'),
                    autofocus: true,
                    initialValue: widget.origConnectData?.address,
                    validator: (String? text) {
                      if (text != null && text.isEmpty) {
                        return 'Cannot be empty';
                      }
                      return null;
                    },
                    onSaved: (String? text) {
                      if (text != null) {
                        newConnectData!.address = text;
                      }
                    },
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
