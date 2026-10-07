import 'package:flutter/material.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stack) {
    debugPrint('Database initialization failed: $error\n$stack');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fall Festival Roster',
    home: RosterScreen(helper: helper),
  );
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _selectedId;
  bool _busy = true;
  bool _loaded = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _read() async {
    final rows = await widget.helper.queryAllRows();
    final count = await widget.helper.queryRowCount();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _count = count;
      _loaded = true;
      _error = null;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _read();
    } catch (error, stack) {
      debugPrint('Read failed: $error\n$stack');
      if (mounted) {
        setState(
          () => _error = 'Could not read records. Tap Refresh to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _selectedId = null;
    _name.clear();
    _age.clear();
    _form.currentState?.reset();
  }

  Future<void> _write(
    Future<int> Function() operation, {
    required bool inserting,
    required String verb,
    required bool clear,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    bool completed = false;
    try {
      final result = await operation();
      completed = true;
      if (!mounted) return;
      setState(() {
        if (inserting || result == 1) {
          _feedback = inserting
              ? 'Added guest ID $result.'
              : '$verb: $result row affected.';
          if (clear) _clearForm();
        } else {
          _feedback = result == 0
              ? 'Record no longer exists. No rows changed.'
              : 'Unexpected result: $result rows affected. Check the roster.';
        }
      });
      await _read();
    } catch (error, stack) {
      debugPrint('$verb failed (write completed: $completed): $error\n$stack');
      if (mounted) {
        setState(
          () => _error = completed
              ? 'Write completed, but refresh failed. Tap Refresh to reload.'
              : '$verb failed. Your input is preserved. Check the logs and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final id = _selectedId;
    final row = <String, dynamic>{
      DatabaseHelper.columnName: _name.text.trim(),
      DatabaseHelper.columnAge: int.parse(_age.text.trim()),
      DatabaseHelper.columnId: ?id,
    };
    await _write(
      () => id == null ? widget.helper.insert(row) : widget.helper.update(row),
      inserting: id == null,
      verb: id == null ? 'Add' : 'Saved',
      clear: true,
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = row[DatabaseHelper.columnId] as int;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete guest ID $id?'),
        content: Text('Remove ${row[DatabaseHelper.columnName]} (ID $id)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() {
        _busy = false;
        _feedback = 'Deletion canceled. No rows changed.';
      });
      return;
    }
    await _write(
      () => widget.helper.delete(id),
      inserting: false,
      verb: 'Deleted',
      clear: _selectedId == id,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fall Festival Roster')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _form,
              child: Column(
                children: [
                  if (_selectedId != null)
                    Text('Editing guest ID $_selectedId'),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter a nonempty name.'
                        : null,
                  ),
                  TextFormField(
                    controller: _age,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Age (0–130)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    validator: (value) {
                      final age = int.tryParse((value ?? '').trim());
                      return age == null || age < 0 || age > 130
                          ? 'Enter an integer from 0 to 130.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_selectedId == null ? 'Add' : 'Save'),
                      ),
                      if (_selectedId != null)
                        TextButton(
                          onPressed: _busy ? null : () => setState(_clearForm),
                          child: const Text('Cancel edit'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy ? null : _refresh,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_feedback!),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!),
              ),
            Text(
              _loaded
                  ? 'Record count: $_count${_error != null ? ' (last successful read)' : ''}'
                  : 'Record count: —',
            ),
            if (_loaded && !_busy && _error == null && _rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No festival guests yet'),
              ),
            for (final row in _rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID ${row[DatabaseHelper.columnId]} • ${row[DatabaseHelper.columnName]} • Age ${row[DatabaseHelper.columnAge]}',
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _form.currentState?.reset();
                                    _selectedId =
                                        row[DatabaseHelper.columnId] as int;
                                    _name.text =
                                        row[DatabaseHelper.columnName]
                                            as String;
                                    _age.text =
                                        '${row[DatabaseHelper.columnAge]}';
                                    _feedback = null;
                                  }),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _delete(row),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
