import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'second_brain.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT 'Personal',
            content_json TEXT NOT NULL DEFAULT '[]',
            content_plain TEXT NOT NULL DEFAULT '',
            is_locked INTEGER NOT NULL DEFAULT 0,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE attachments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            path TEXT NOT NULL,
            name TEXT,
            mime TEXT,
            sort_index INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('CREATE INDEX idx_notes_updated ON notes(updated_at);');
        await db.execute('CREATE INDEX idx_att_note ON attachments(note_id, sort_index);');
      },
    );
    return _db!;
  }
}
