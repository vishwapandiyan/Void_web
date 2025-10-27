// Web-specific file upload handling
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

class FileData {
  final String name;
  final Uint8List bytes;
  final String contentType;

  FileData({
    required this.name,
    required this.bytes,
    required this.contentType,
  });
}

Future<FileData?> pickPdf(String label) async {
  final html.FileUploadInputElement uploadInput = html.FileUploadInputElement()
    ..accept = 'application/pdf'
    ..multiple = false;

  uploadInput.click();

  await uploadInput.onChange.first;

  if (uploadInput.files!.isEmpty) {
    return null;
  }

  final file = uploadInput.files!.first;
  final reader = html.FileReader();

  reader.readAsDataUrl(file);
  await reader.onLoad.first;

  final result = reader.result as String;
  
  if (result.startsWith('data:application/pdf;base64,')) {
    final base64String = result.split(',').last;
    final bytes = base64Decode(base64String);
    
    return FileData(
      name: file.name,
      bytes: bytes,
      contentType: file.type,
    );
  }
  
  return null;
}
