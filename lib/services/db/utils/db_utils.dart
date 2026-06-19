
/// Utility class for safe database type conversions.
/// Prevents "String is not a subtype of num" and other casting errors.
class DbUtils {
  /// Safely parse a dynamic value to a double.
  static double toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    
    return defaultValue;
  }

  /// Safely parse a dynamic value to an int.
  static int toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    
    if (value is String) {
      // Handle potential decimal strings by parsing as double first
      final d = double.tryParse(value);
      return d?.toInt() ?? defaultValue;
    }
    
    return defaultValue;
  }

  /// Safely parse a dynamic value to a String.
  static String toStringValue(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  /// Safely parse a dynamic value to a bool.
  static bool toBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final s = value.toLowerCase();
      return s == '1' || s == 'true';
    }
    return defaultValue;
  }
}
