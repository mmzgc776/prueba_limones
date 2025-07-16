import 'package:flutter/material.dart';
import 'dart:developer' as developer;

// Singleton class to manage logs
class LogManager {
  static final LogManager _instance = LogManager._internal();
  factory LogManager() => _instance;
  LogManager._internal();

  List<Map<String, dynamic>> _logs = [];

  List<Map<String, dynamic>> get logs => _logs;

  void log(String message) {
    final now = DateTime.now();
    developer.log(message, time: now);
    _logs.add({'time': now, 'message': message});
    // Limit to the last 100 logs to prevent memory issues
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
  }

  void clearLogs() {
    _logs.clear();
  }
}

// Function to log messages from anywhere in the app
void appLog(String message) {
  LogManager().log(message);
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  @override
  void initState() {
    super.initState();
    // Ensure some initial logs for demonstration if none exist
    if (LogManager().logs.isEmpty) {
      appLog('Logs page opened');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                LogManager().clearLogs();
              });
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: LogManager().logs.length,
        itemBuilder: (context, index) {
          final log = LogManager().logs[index];
          return ListTile(
            title: Text(
              '${log['time'].toString()} - ${log['message']}',
              style: const TextStyle(fontSize: 14),
            ),
          );
        },
      ),
    );
  }
}
