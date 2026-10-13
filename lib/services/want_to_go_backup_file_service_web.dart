import 'dart:html' as html;

bool get supportsWantToGoBackupFiles => true;

Future<bool> downloadWantToGoBackup({
  required String contents,
  required String fileName,
}) async {
  final backupFile = html.Blob(<String>[contents], 'application/json');
  final objectUrl = html.Url.createObjectUrlFromBlob(backupFile);
  final downloadLink = html.AnchorElement(href: objectUrl)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(downloadLink);
  downloadLink.click();
  downloadLink.remove();
  html.Url.revokeObjectUrl(objectUrl);
  return true;
}

Future<String?> pickWantToGoBackup() async {
  final filePicker = html.FileUploadInputElement()
    ..accept = '.json,application/json';
  filePicker.click();
  await filePicker.onChange.first;

  final selectedFile = filePicker.files?.firstOrNull;
  if (selectedFile == null) return null;

  final reader = html.FileReader()..readAsText(selectedFile);
  await reader.onLoad.first;
  return reader.result as String?;
}
