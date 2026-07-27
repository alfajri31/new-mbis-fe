import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/customer_provider.dart';

/// Halaman daftar nasabah — exemplar arsitektur target (layered + Riverpod).
/// `ConsumerWidget` membaca state via `ref.watch`; tanpa `setState` untuk state bisnis.
class CustomerListPage extends ConsumerWidget {
  const CustomerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nasabah')),
      body: customers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(customerListProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final c = items[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text('${c.entityCategory ?? '-'} · ${c.state ?? '-'}'),
                trailing: Text('${c.pipelineCount}'),
              );
            },
          ),
        ),
      ),
    );
  }
}
