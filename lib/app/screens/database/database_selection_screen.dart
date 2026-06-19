import 'package:chifa/services/db/database_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  const DatabaseSelectionScreen({super.key});

  @override
  State<DatabaseSelectionScreen> createState() =>
      _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  bool _isLoading = false;
  String _selectedDatabaseType = 'xampp'; // Default option
  bool _rememberChoice = false;

  Future<void> _initializeDatabaseConnection() async {
    setState(() => _isLoading = true);

    try {
      // Pass the selected database type to the initialization function
      await DatabaseManager.initialize(databaseType: _selectedDatabaseType);

      if (_rememberChoice) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_database_choice', true);
        await prefs.setString('database_type', _selectedDatabaseType);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (_selectedDatabaseType == 'octenium')
                  ? 'Successfully connected to Remote Database (Octenium)! 🚀'
                  : 'Successfully connected to Local Database!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to database: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Connection')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.computer, size: 100, color: Colors.blue),
              const SizedBox(height: 32),
              const Text(
                'Select Database Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'xampp', label: Text('XAMPP (Local)')),
                  ButtonSegment(value: 'octenium', label: Text('Octenium')),
                ],
                selected: {_selectedDatabaseType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedDatabaseType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _rememberChoice,
                    onChanged: (value) {
                      setState(() {
                        _rememberChoice = value ?? false;
                      });
                    },
                  ),
                  const Text('Remember my choice'),
                ],
              ),
              const SizedBox(height: 32),
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Establishing connection to database'),
              ] else ...[
                ElevatedButton(
                  onPressed: _initializeDatabaseConnection,
                  child: const Text('Connect to Database'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
