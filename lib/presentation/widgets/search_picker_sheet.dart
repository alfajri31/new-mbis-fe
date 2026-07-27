import 'package:flutter/material.dart';
import '../../core/utils/debouncer.dart';
import '../../theme/app_theme.dart';

/// Generic searchable bottom-sheet picker.
///
/// Kept as a proper StatefulWidget (not a builder-local StatefulBuilder)
/// so the search text and results survive rebuilds triggered by keyboard
/// show/hide (a MediaQuery change): when the text/controller lived as a
/// local variable inside showModalBottomSheet's `builder` callback, that
/// callback re-ran on every such rebuild and silently reset the search —
/// tapping anywhere to dismiss the keyboard wiped out what the user typed.
Future<T?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> initial,
  required String Function(T) labelOf,
  required Future<List<T>> Function(String) onSearch,
  String emptyLabel = 'Ketik untuk mencari',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetCtx) => _SearchPickerSheet<T>(
      title: title,
      initial: initial,
      labelOf: labelOf,
      onSearch: onSearch,
      emptyLabel: emptyLabel,
    ),
  );
}

class _SearchPickerSheet<T> extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.initial,
    required this.labelOf,
    required this.onSearch,
    required this.emptyLabel,
  });

  final String title;
  final List<T> initial;
  final String Function(T) labelOf;
  final Future<List<T>> Function(String) onSearch;
  final String emptyLabel;

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  final _ctrl = TextEditingController();
  // onSearch bisa memanggil server (mis. cabang bank), jadi di-debounce agar tidak
  // menembak API tiap ketukan. _seq menjaga respon lama tak menimpa hasil terbaru.
  final _debounce = Debouncer();
  int _seq = 0;
  late List<T> _results = widget.initial;

  @override
  void dispose() {
    _debounce.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    final r = await widget.onSearch(q);
    if (!mounted || seq != _seq) return;
    setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    // Cap against the area above the keyboard, not the full screen —
    // otherwise content + keyboard inset pushes the sheet to the very top.
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: mq.viewInsets.bottom + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: (mq.size.height - mq.viewInsets.bottom) * 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.grayStage),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              ),
              onChanged: (q) => _debounce.run(() => _search(q.trim())),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text(widget.emptyLabel,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(widget.labelOf(_results[i]),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                        onTap: () => Navigator.of(context).pop(_results[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
