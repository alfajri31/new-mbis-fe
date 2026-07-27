import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../src/dashboard/dashboard_repository.dart';

/// Searchable RM picker used by the supervisor monitoring views (Customer filter,
/// scoped export). Queries /api/dashboard/rm-options (debounced), scoped to the chosen
/// wilayah/cabang, and returns the pick via [onSelected] (null = "Semua RM"). Show it
/// with [showModalBottomSheet].
class RmPickerSheet extends StatefulWidget {
  final DashboardRepository repo;
  final String? regionId;
  final String? branchId;
  final void Function(RmOption?) onSelected;

  const RmPickerSheet({
    super.key,
    required this.repo,
    required this.regionId,
    required this.branchId,
    required this.onSelected,
  });

  @override
  State<RmPickerSheet> createState() => _RmPickerSheetState();
}

class _RmPickerSheetState extends State<RmPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<RmOption> _options = const [];
  bool _loading = true;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String term) async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.repo.getRmOptions(
        regionId: widget.regionId,
        branchId: widget.branchId,
        search: term,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _options = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: [
                      const Text('Pilih RM',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bgScreen,
                      borderRadius: AppRadius.radiusFull,
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _onChanged,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama / NIP RM',
                        hintStyle:
                            TextStyle(color: AppColors.grayStage, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppColors.grayStage, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)))
                      : ListView(
                          controller: scrollController,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.groups_rounded,
                                  color: AppColors.grayStage),
                              title: const Text('Semua RM'),
                              onTap: () {
                                widget.onSelected(null);
                                Navigator.of(context).pop();
                              },
                            ),
                            const Divider(height: 1),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (_options.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                    child: Text('Tidak ada RM ditemukan',
                                        style: TextStyle(
                                            color: AppColors.textSecondary))),
                              )
                            else
                              ..._options.map((rm) => ListTile(
                                    leading: const Icon(Icons.person_rounded,
                                        color: AppColors.primaryNavy),
                                    title: Text(rm.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: rm.officeName != null
                                        ? Text(rm.officeName!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)
                                        : null,
                                    onTap: () {
                                      widget.onSelected(rm);
                                      Navigator.of(context).pop();
                                    },
                                  )),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
