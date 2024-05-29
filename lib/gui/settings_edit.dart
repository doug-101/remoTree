// settings_edit.dart, a view to edit the app's preferences.
// remoTree, an sftp-based remote file manager.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'common_dialogs.dart';
import '../main.dart'
    show prefs, minWidth, minHeight, allowSaveWindowGeo, saveWindowGeo;
import '../model/file_interface.dart';
import '../model/sort_rule.dart';
import '../model/theme_model.dart';

/// A user settings view.
class SettingEdit extends StatefulWidget {
  const SettingEdit({super.key});

  @override
  State<SettingEdit> createState() => _SettingEditState();
}

class _SettingEditState extends State<SettingEdit> {
  /// A flag showing that the view was forced to close.
  var _cancelFlag = false;

  final _formKey = GlobalKey<FormState>();
  final origViewScale = prefs.getDouble('view_scale') ?? 1.0;
  final origSort = SortRule.fromPrefs();

  /// Prepare to close by validating and updating.
  ///
  /// Returns true if it's ok to close.
  Future<bool> _handleClose() async {
    if (_cancelFlag) return true;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final viewScale = prefs.getDouble('view_scale') ?? 1.0;
      if (viewScale != origViewScale &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final currentSize = await windowManager.getSize();
        var currentWidth = currentSize.width;
        var currentHeight = currentSize.height;
        if (currentWidth < minWidth * viewScale) {
          currentWidth = minWidth * viewScale;
        }
        if (currentHeight < minHeight * viewScale) {
          currentHeight = minHeight * viewScale;
        }
        if (currentWidth != currentSize.width ||
            currentHeight != currentSize.height) {
          await windowManager.setSize(Size(currentWidth, currentHeight));
        }
        await windowManager.setMinimumSize(
          Size(minWidth * viewScale, minHeight * viewScale),
        );
      }
      if (!mounted) return false;
      final localModel = Provider.of<LocalInterface>(context, listen: false);
      final remoteModel = Provider.of<RemoteInterface>(context, listen: false);
      if (origSort != SortRule.fromPrefs()) {
        localModel.changeSortRule(SortRule.fromPrefs());
        remoteModel.changeSortRule(SortRule.fromPrefs());
      } else {
        localModel.updateViews();
        remoteModel.updateViews();
      }
      final themeModel = Provider.of<ThemeModel>(context, listen: false);
      themeModel.updateTheme();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings - remoTree'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close without saving',
            onPressed: () {
              _cancelFlag = true;
              Navigator.pop(context, null);
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (!didPop && await _handleClose()) {
            // Pop manually (bypass canPop) if update is complete.
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400.0,
              child: ListView(
                children: <Widget>[
                  SortFormField(
                    initialValue: SortRule.fromPrefs(),
                    onSaved: (SortRule? value) async {
                      if (value != null) {
                        await value.saveToPrefs();
                      }
                    },
                  ),
                  BoolFormField(
                    initialValue: prefs.getBool('hide_dot_files') ?? true,
                    heading: 'Hide dot files at startup',
                    onSaved: (bool? value) async {
                      if (value != null) {
                        await prefs.setBool('hide_dot_files', value);
                      }
                    },
                  ),
                  TextFormField(
                    initialValue:
                        (prefs.getDouble('view_scale') ?? 1.0).toString(),
                    decoration: const InputDecoration(
                      labelText: 'App view scale ratio',
                    ),
                    validator: (String? value) {
                      if (value != null && value.isNotEmpty) {
                        final scale = double.tryParse(value);
                        if (scale == null) {
                          return 'Must be an number';
                        }
                        if (scale > 4.0 || scale < 0.25) {
                          return 'Valid range is 0.25 to 4.0';
                        }
                      }
                      return null;
                    },
                    onSaved: (String? value) async {
                      if (value != null && value.isNotEmpty) {
                        await prefs.setDouble(
                            'view_scale', double.parse(value));
                      }
                    },
                  ),
                  if (defaultTargetPlatform == TargetPlatform.linux ||
                      defaultTargetPlatform == TargetPlatform.windows ||
                      defaultTargetPlatform == TargetPlatform.macOS)
                    BoolFormField(
                      initialValue: prefs.getBool('save_window_geo') ?? true,
                      heading: 'Remember Window Position and Size',
                      onSaved: (bool? value) async {
                        if (value != null) {
                          await prefs.setBool('save_window_geo', value);
                          allowSaveWindowGeo = value;
                          if (allowSaveWindowGeo) saveWindowGeo();
                        }
                      },
                    ),
                  BoolFormField(
                    initialValue: prefs.getBool('dark_theme') ?? false,
                    heading: 'Use dark color theme',
                    onSaved: (bool? value) async {
                      if (value != null) {
                        await prefs.setBool('dark_theme', value);
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

/// A [FormField] widget for boolean settings.
class BoolFormField extends FormField<bool> {
  BoolFormField({
    super.initialValue,
    String? heading,
    super.key,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<bool> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: () {
                    state.didChange(!state.value!);
                  },
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(heading ?? 'Boolean Value'),
                      ),
                      Switch(
                        value: state.value!,
                        onChanged: (bool value) {
                          state.didChange(!state.value!);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(
                  thickness: 3.0,
                  height: 6.0,
                ),
              ],
            );
          },
        );
}

/// A [FormField] widget for setting the default sorting method.
class SortFormField extends FormField<SortRule> {
  SortFormField({
    super.initialValue,
    String? heading,
    super.key,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<SortRule> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InkWell(
                  onTap: () async {
                    SortRule? rule = await sortRuleDialog(
                      context: state.context,
                      initialRule: state.value!,
                    );
                    if (rule != null) {
                      state.didChange(rule);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(heading ?? 'Default Sorting',
                            style: Theme.of(state.context).textTheme.bodySmall),
                      ),
                      Text(
                        state.value!.toString(),
                        style: Theme.of(state.context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(
                  thickness: 3.0,
                  height: 9.0,
                ),
              ],
            );
          },
        );
}
