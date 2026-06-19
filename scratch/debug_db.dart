import 'package:chifa/services/db/database.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseManager.initialize();
  final db = DatabaseService();
  
  print('Checking medicalrecords table...');
  final tables = await db.getTables();
  print('Tables: $tables');
  
  if (tables.contains('medicalrecords')) {
    final columns = await db.query('DESCRIBE medicalrecords');
    print('Columns in medicalrecords:');
    for (var col in columns) {
      print(' - ${col['Field']}: ${col['Type']}');
    }
  } else {
    print('Table medicalrecords NOT FOUND!');
  }
}
