class AppConstants {
  static const String appName = 'Second Brain';
  static const String appVersion = '1.0.0';
  
  // Database
  static const String databaseName = 'second_brain.db';
  static const int databaseVersion = 1;
  
  // Categories
  static const List<String> defaultCategories = [
    'Personal',
    'Work', 
    'Ideas'
  ];
  
  // File types
  static const String fileTypeImage = 'image';
  static const String fileTypePdf = 'pdf';
  static const String fileTypeAudio = 'audio';
  static const String fileTypeVideo = 'video';
  static const String fileTypeUrl = 'url';
  static const String fileTypeDocument = 'document';
}