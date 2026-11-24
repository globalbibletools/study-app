List<Map<String, Object?>> parseBackupRows(Object? rows, String table) {
  if (rows is! List) {
    throw FormatException('Backup table payload for $table is invalid.');
  }

  return rows.map((row) {
    if (row is! Map) {
      throw FormatException('Backup row payload for $table is invalid.');
    }
    return Map<String, Object?>.from(row);
  }).toList();
}

Map<String, Object?> pickBackupColumns(
  Map<String, Object?> row,
  Iterable<String> columns,
) {
  return {
    for (final column in columns)
      if (row.containsKey(column)) column: row[column],
  };
}
