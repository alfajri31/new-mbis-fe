import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/widgets/pipeline_detail/pipeline_pengelola_card.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';

void main() {
  testWidgets('renders non-BUMN pengelola information properly', (tester) async {
    final pipeline = PipelineDetailModel(
      id: 'PL-001',
      stage: 'P1',
      tsiIdr: 100000000,
      rmName: 'Mohammad Ridwan Majid',
      rmJabatan: 'Associate II RM',
      rmNip: '199002142016',
      kanwil: 'Kantor Wilayah 1',
      kc: 'Padang',
      isBumn: false,
      schedules: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PipelinePengelolaCard(pipeline: pipeline),
        ),
      ),
    ));

    expect(find.text('Informasi Pengelola'), findsOneWidget);
    expect(find.text('BUMN'), findsNothing);
    expect(find.text('MR'), findsOneWidget);
    expect(find.text('RM Penanggung Jawab'), findsOneWidget);
    expect(find.text('Mohammad Ridwan Majid'), findsOneWidget);
    expect(find.text('Associate II RM · NIP 199002142016'), findsOneWidget);
    expect(find.text('Kantor Wilayah'), findsOneWidget);
    expect(find.text('Kantor Wilayah 1'), findsOneWidget);
    expect(find.text('Kantor Cabang'), findsOneWidget);
    expect(find.text('KC Padang'), findsOneWidget);
    expect(find.text('Entitas BUMN'), findsNothing);
  });

  testWidgets('renders BUMN pengelola information with badge, entitas, and grup', (tester) async {
    final pipeline = PipelineDetailModel(
      id: 'PL-002',
      stage: 'P2',
      tsiIdr: 500000000,
      rmName: 'Siti Rahmawati',
      rmJabatan: 'Senior RM',
      rmNip: '198905122015',
      kanwil: 'Kantor Wilayah 2',
      kc: 'KC Jakarta Selatan',
      isBumn: true,
      bumnRelasi: 'Anak usaha',
      bumnGroup: 'BANK MANDIRI',
      schedules: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PipelinePengelolaCard(pipeline: pipeline),
        ),
      ),
    ));

    expect(find.text('Informasi Pengelola'), findsOneWidget);
    expect(find.text('BUMN'), findsOneWidget);
    expect(find.text('SR'), findsOneWidget);
    expect(find.text('Siti Rahmawati'), findsOneWidget);
    expect(find.text('Senior RM · NIP 198905122015'), findsOneWidget);
    expect(find.text('Kantor Wilayah 2'), findsOneWidget);
    expect(find.text('KC Jakarta Selatan'), findsOneWidget);
    expect(find.text('Entitas BUMN'), findsOneWidget);
    expect(find.text('Anak usaha'), findsOneWidget);
    expect(find.text('Grup BUMN'), findsOneWidget);
    expect(find.text('BANK MANDIRI'), findsOneWidget);
  });
}
