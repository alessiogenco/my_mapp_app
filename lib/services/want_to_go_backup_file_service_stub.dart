bool get supportsWantToGoBackupFiles => false;

Future<bool> downloadWantToGoBackup({
  required String contents,
  required String fileName,
}) async {
  return false;
}

Future<String?> pickWantToGoBackup() async {
  return null;
}
