import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/screens/bumn_screen.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';

/// Mencari nama sebuah Induk harus ikut memunculkan Anak-anaknya.
///
/// Dilaporkan 2026-08-20: setelah membuat Induk baru + Anak yang menyambung ke induk
/// itu, panah di layar BUMN "tidak bisa dipencet". Dua sebab bertumpuk. (1) Filter
/// pencarian menyaring anak dengan kata kunci yang SAMA, jadi Induk yang cocok muncul
/// sendirian tanpa anaknya. (2) Di mode pencarian chevron-nya dirender sebagai Icon
/// mati — bentuknya identik dengan tombol, tapi tap-nya diabaikan — sehingga terbaca
/// sebagai kontrol rusak.
BumnTreeCustomer _node(String id, String name,
        {List<BumnTreeCustomer> children = const []}) =>
    BumnTreeCustomer(id: id, name: name, children: children);

void main() {
  // Persis bentuk data yang dilaporkan.
  final kefas = _node('B2', 'kefas');
  final rakaDaffa = _node('B1', 'raka daffa', children: [kefas]);
  final lain = _node('B3', 'PT Lain');
  final roots = [rakaDaffa, lain];

  List<String> namesOf(String query, {Set<String> collapsed = const {}}) =>
      bumnSearchRows(roots, query, collapsed).map((r) => r.node.name).toList();

  test('mencari nama induk ikut memunculkan anaknya', () {
    expect(namesOf('raka'), ['raka daffa', 'kefas']);
  });

  test('mencari nama anak tetap memunculkan induknya sebagai jalur', () {
    expect(namesOf('kefas'), ['raka daffa', 'kefas']);
  });

  test('cabang yang tidak cocok tidak ikut muncul', () {
    expect(namesOf('raka'), isNot(contains('PT Lain')));
  });

  test('kedalaman baris mengikuti hierarki', () {
    final rows = bumnSearchRows(roots, 'raka', const {});
    expect(rows.map((r) => r.depth).toList(), [0, 1]);
  });

  test('cabang yang ditutup manual menyembunyikan anaknya', () {
    expect(namesOf('raka', collapsed: {'B1'}), ['raka daffa']);
  });

  test('seluruh keturunan ikut, bukan hanya satu tingkat', () {
    final cucu = _node('C1', 'cucu');
    final anak = _node('C2', 'anak', children: [cucu]);
    final induk = _node('C3', 'induk baru', children: [anak]);
    expect(
      bumnSearchRows([induk], 'induk baru', const {}).map((r) => r.node.name),
      ['induk baru', 'anak', 'cucu'],
    );
  });
}
