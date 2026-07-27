// Native (mobile/desktop) file opener. Used when dart:html is unavailable
// (see file_opener.dart's conditional export). Writes the fetched bytes to a
// temp file and hands it to the OS viewer (e.g. a PDF reader). Signatures mirror
// file_opener_web.dart so callers compile and behave the same on every platform.
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// No browser-tab concept off the web.
Object? openPendingTab() => null;

/// Saves [bytes] to a temporary file named [fileName] and opens it with the OS's
/// default viewer for [mimeType]. Returns true if a handler launched successfully.
/// [pending] is ignored here (web-only).
Future<bool> openBytes(List<int> bytes, String mimeType, String fileName, {Object? pending}) async {
  // Sanitize: strip path separators and fall back to a generic name so the OS
  // still gets a sensible file (extension drives which viewer Android picks).
  final safeName = fileName.replaceAll(RegExp(r'[\\/]+'), '_').trim();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${safeName.isEmpty ? 'document' : safeName}');
  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(
    file.path,
    type: mimeType.isEmpty ? null : mimeType,
  );
  return result.type == ResultType.done;
}

/// No-op off the web.
void closePendingTab(Object? pending) {}

/// Off the web there is no save-as dialog — save to temp and hand to the OS
/// viewer, same as [openBytes] (spreadsheet apps register for text/csv).
Future<bool> downloadBytes(List<int> bytes, String mimeType, String fileName) =>
    openBytes(bytes, mimeType, fileName);
