import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/providers/add_activity_provider.dart';
import 'package:mbis/presentation/providers/add_pipeline_provider.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

/// Regresi BUG RM: tombol "Simpan Pipeline" macet loading + tak bisa ditekan
/// SETELAH satu pipeline berhasil ditambahkan.
///
/// Penyebabnya bukan backend. Notifier layar tambah adalah `NotifierProvider`
/// biasa — di Riverpod 3 defaultnya `isAutoDispose: false`, jadi state-nya hidup
/// terus setelah layar ditutup. Jalur SUKSES dulu tidak pernah mereset
/// `saving`, karena versi `setState` lama mati bersama widget. Akibatnya
/// pembukaan layar berikutnya mewarisi `saving: true` → tombol tampil spinner
/// dan `onPressed: null` selamanya.
///
/// Test ini mengunci invarian: apa pun hasilnya (sukses ATAU gagal), `saving`
/// harus kembali `false` setelah operasi simpan selesai.
class _FakePipelineRepository extends PipelineRepository {
  _FakePipelineRepository({this.fail = false}) : super(apiClient: ApiClient());

  final bool fail;

  @override
  Future<PipelineListModel> addPipeline(Map<String, dynamic> data) async {
    if (fail) throw Exception('gagal simpan');
    return PipelineListModel.fromJson({'id': 'p1', 'customerId': 'c1'});
  }
}

class _FakeVisitRepository extends VisitRepository {
  _FakeVisitRepository({this.fail = false}) : super(apiClient: ApiClient());

  final bool fail;

  @override
  Future<Map<String, dynamic>> createVisit({
    required String pipelineId,
    required String type,
    String? notes,
    String? nextFollowupDate,
    String? actionPlan,
    String? gpsLatitude,
    String? gpsLongitude,
    List<int>? photoBytes,
    String? photoName,
  }) async {
    if (fail) throw Exception('gagal simpan');
    return {'id': 'v1'};
  }
}

void main() {
  group('AddPipelineNotifier.save', () {
    test('reset saving setelah SUKSES (regresi tombol macet loading)', () async {
      final container = ProviderContainer(
        overrides: [
          pipelineRepoProvider.overrideWithValue(_FakePipelineRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addPipelineProvider.notifier);
      final error = await notifier.save({'customerId': 'c1'});

      expect(error, isNull, reason: 'simpan seharusnya sukses');
      expect(
        container.read(addPipelineProvider).saving,
        isFalse,
        reason:
            'saving harus kembali false; kalau tidak, tombol Simpan pada '
            'pembukaan layar berikutnya macet loading + nonaktif',
      );
    });

    test('reset saving setelah GAGAL', () async {
      final container = ProviderContainer(
        overrides: [
          pipelineRepoProvider.overrideWithValue(
            _FakePipelineRepository(fail: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(addPipelineProvider.notifier)
          .save({'customerId': 'c1'});

      expect(error, isNotNull);
      expect(container.read(addPipelineProvider).saving, isFalse);
    });

    test('simpan kedua tetap bisa jalan (state tidak diwarisi kotor)', () async {
      final container = ProviderContainer(
        overrides: [
          pipelineRepoProvider.overrideWithValue(_FakePipelineRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(addPipelineProvider.notifier);
      await notifier.save({'customerId': 'c1'});
      // Layar ditutup lalu dibuka lagi — provider keepAlive, state yang sama.
      expect(container.read(addPipelineProvider).saving, isFalse);
      await notifier.save({'customerId': 'c2'});
      expect(container.read(addPipelineProvider).saving, isFalse);
    });
  });

  group('AddActivityNotifier.submit', () {
    test('reset saving setelah SUKSES', () async {
      final container = ProviderContainer(
        overrides: [visitRepoProvider.overrideWithValue(_FakeVisitRepository())],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(addActivityProvider.notifier)
          .submit(pipelineId: 'p1', type: 'VISIT', notes: 'catatan');

      expect(ok, isTrue);
      expect(container.read(addActivityProvider).saving, isFalse);
    });

    test('reset saving setelah GAGAL + pesan error terisi', () async {
      final container = ProviderContainer(
        overrides: [
          visitRepoProvider.overrideWithValue(_FakeVisitRepository(fail: true)),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(addActivityProvider.notifier)
          .submit(pipelineId: 'p1', type: 'VISIT', notes: 'catatan');

      expect(ok, isFalse);
      expect(container.read(addActivityProvider).saving, isFalse);
      expect(container.read(addActivityProvider).error, isNotNull);
    });
  });
}
