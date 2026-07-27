# State Management MBIS-App — Penjelasan Mudah

- **Tanggal:** 2026-07-22
- **Ditulis untuk:** memahami *bagaimana* aplikasi Flutter ini mengelola "state", dan **sejauh mana Riverpod sudah dipakai**.
- **Basis:** hasil pembacaan langsung kode di `lib/` (bukan asumsi). Angka & file nyata dicantumkan.

---

## 0. Jawaban singkat (TL;DR)

> **Apakah sudah pakai Riverpod?**
> **Sudah — tapi baru fondasinya + 1 modul contoh.** Riverpod sudah dipasang dan
> dinyalakan di akar aplikasi, dan ada **satu modul (`customer`)** yang benar-benar
> memakai Riverpod sebagai *contoh/teladan* (exemplar). **Sisanya — mayoritas layar
> yang benar-benar jalan — masih memakai cara lama (`setState`).**

Angka nyata dari kode saat ini:

| Indikator | Nilai | Artinya |
|---|---|---|
| `flutter_riverpod` di `pubspec.yaml` | **^3.3.2** terpasang | Riverpod tersedia |
| `ProviderScope` di `main.dart` | **Ada** (baris 44) | "Sakelar utama" Riverpod sudah ON |
| Layar/kelas yang **benar-benar** pakai Riverpod | **1 modul** (`features/customer`, 2 file) | Baru teladan |
| Panggilan `setState` (cara lama) | **505 panggilan di 57 file** | Mayoritas app masih cara lama |
| Modul contoh sudah tersambung ke navigasi app? | **Belum** (masih pakai data *mock*) | Teladan, belum dipakai user |

**Kesimpulan:** statusnya **"migrasi baru dimulai"**. Polanya sudah dibuktikan lewat 1 modul,
tapi ~95% aplikasi belum dipindahkan. Ini memang sesuai rencana: **migrasi bertahap per modul.**

---

## 1. Apa itu "state" dan "state management"? (analogi sederhana)

**State** = "kondisi/data yang sedang ditampilkan atau dipegang layar saat ini."
Contoh di aplikasi ini:
- Daftar nasabah yang sedang tampil.
- Apakah sedang *loading* (memuat) atau sudah selesai.
- Isi form "Tambah Pipeline" yang sedang diketik.
- Siapa user yang login (sesi/token).

**State management** = "cara/aturan bagaimana data itu disimpan, diubah, dan
disampaikan ke tampilan agar layar ikut ter-update saat datanya berubah."

> **Analogi dapur restoran:**
> - **State** = pesanan yang sedang dimasak.
> - **`setState` (cara lama)** = tiap koki mencatat pesanannya di kertas tempel di
>   meja masing‑masing. Cepat untuk 1 meja, tapi kalau pesanan yang sama dibutuhkan
>   meja lain, harus disalin manual dan gampang tidak sinkron.
> - **Riverpod (cara baru)** = ada **papan pusat pesanan**. Semua koki melihat papan
>   yang sama; kalau status pesanan berubah di papan, semua yang "berlangganan"
>   otomatis lihat perubahannya. Lebih rapi, konsisten, dan mudah diuji.

---

## 2. Dua "dunia" di dalam `lib/` (penting dipahami)

Kode aplikasi ini sekarang **campuran dua gaya** yang hidup berdampingan:

```
lib/
├── main.dart            ← menyalakan ProviderScope (Riverpod) untuk SELURUH app
│
├── (DUNIA LAMA — yang benar-benar jalan sekarang)
│   ├── src/             ← app.dart, nav.dart (go_router), repository per domain
│   ├── presentation/    ← screens/ + widgets/  ← DI SINI 505 setState berada
│   └── data/            ← model & data lama
│
└── (DUNIA BARU — arsitektur target, baru 1 modul)
    └── features/
        └── customer/
            ├── data/        → repositories (api_, mock_, interface)
            ├── domain/      → entities (customer.dart) — inti murni, tanpa Flutter
            └── presentation/
                ├── pages/       → customer_list_page.dart  (ConsumerWidget)
                └── providers/    → customer_provider.dart   (AsyncNotifier)
```

- **Dunia lama** = mayoritas fitur yang RM/Agen pakai hari ini (nasabah, pipeline,
  kunjungan, dll). Pakai `setState`.
- **Dunia baru** = pola tujuan (layered + Riverpod). Baru berisi **1 modul teladan**
  (`customer`) untuk membuktikan polanya dan jadi cetakan modul berikutnya.

> Keduanya bisa hidup bersama karena `ProviderScope` bersifat **aditif** — ia tidak
> mengganggu kode lama yang belum pakai Riverpod, tapi mengaktifkan modul yang sudah pakai.

---

## 3. "Cara lama": `setState` — seperti apa & kenapa mau diganti

Di layar lama, data dan logika ada **di dalam widget layar**, dan tampilan di-refresh
dengan memanggil `setState(() => ... )`. Pola khasnya:

```dart
class AddPipelineScreen extends StatefulWidget { ... }

class _AddPipelineScreenState extends State<AddPipelineScreen> {
  bool _loading = false;         // state disimpan di dalam layar
  List<Customer> _customers = [];

  Future<void> _load() async {
    setState(() => _loading = true);            // "gambar ulang: sedang loading"
    _customers = await repo.getCustomers();     // ambil data langsung di layar
    setState(() => _loading = false);           // "gambar ulang: selesai"
  }
}
```

Contoh nyata file terbanyak `setState` di repo ini:

| File | Jumlah `setState` |
|---|---|
| `lib/presentation/screens/kelola_master_data_screen.dart` | 81 |
| `lib/presentation/screens/add_pipeline_screen.dart` | 37 |
| `lib/presentation/screens/add_customer_screen.dart` | 32 |
| `lib/presentation/screens/pipeline_detail_screen.dart` | 27 |
| `lib/presentation/screens/assistant_screen.dart` | 23 |

**Kelemahan cara ini** (kenapa tim memutuskan pindah ke Riverpod):
1. **Logika bisnis nyampur dengan tampilan** → layar jadi besar & sulit dibaca.
2. **Data sulit dibagi antar layar** → sering diambil ulang / tidak sinkron.
3. **Susah dites** → karena logika terkunci di dalam widget.
4. **Loading/error ditangani manual** tiap layar (banyak `bool _loading`, `try/catch` berulang).

---

## 4. "Cara baru": Riverpod — bagaimana modul `customer` melakukannya

Modul `customer` adalah **contoh lengkap** pola target. Ada 3 lapisan + Riverpod.
Mari lihat 2 file intinya (ini kode ASLI dari repo, dijelaskan baris per baris).

### 4a. "Papan pusat" — file provider

`lib/features/customer/presentation/providers/customer_provider.dart`:

```dart
// (1) Repository di-"pasang" sebagai provider. Saat test/dev bisa diganti (mock).
final customerRepositoryProvider =
    Provider<CustomerRepository>((ref) => MockCustomerRepository());

// (2) State daftar nasabah: loading/error/data dibungkus otomatis oleh AsyncValue.
final customerListProvider =
    AsyncNotifierProvider<CustomerListNotifier, List<Customer>>(
        CustomerListNotifier.new);

// (3) "Otak"-nya: ambil data + sediakan aksi refresh.
class CustomerListNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() =>            // dipanggil otomatis saat pertama dibutuhkan
      ref.read(customerRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();               // umumkan "sedang loading"
    state = await AsyncValue.guard(             // ambil ulang; error otomatis tertangkap
        () => ref.read(customerRepositoryProvider).list());
  }
}
```

Penjelasan mudah:
- **(1)** `customerRepositoryProvider` = "colokan" sumber data. Sekarang isinya `Mock`
  (data palsu untuk contoh/test). Nanti tinggal diganti ke `ApiCustomerRepository`
  (data asli dari MBIS-Backend) **tanpa mengubah tampilan**.
- **(2)** `customerListProvider` = "papan pusat" berisi daftar nasabah. Tipenya
  `AsyncValue`, artinya ia **otomatis** punya 3 keadaan: *loading*, *error*, *data*.
- **(3)** `CustomerListNotifier` = otak yang mengisi papan. `build()` = ambil data awal;
  `refresh()` = ambil ulang saat user tarik‑refresh. Tidak ada `setState` sama sekali.

### 4b. "Layar yang berlangganan papan" — file halaman

`lib/features/customer/presentation/pages/customer_list_page.dart`:

```dart
class CustomerListPage extends ConsumerWidget {          // ConsumerWidget = bisa "dengar" provider
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customerListProvider);   // (A) berlangganan papan pusat
    return Scaffold(
      appBar: AppBar(title: const Text('Nasabah')),
      body: customers.when(                              // (B) satu tempat menangani 3 keadaan
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Gagal memuat: $e')),
        data:    (items) => RefreshIndicator(
          onRefresh: () => ref.read(customerListProvider.notifier).refresh(), // (C) panggil aksi
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(title: Text(items[i].name)),
          ),
        ),
      ),
    );
  }
}
```

Penjelasan mudah:
- **(A) `ref.watch(...)`** = layar "berlangganan" papan pusat. Kalau isi papan berubah,
  layar **otomatis** menggambar ulang. **Tidak perlu `setState`.**
- **(B) `.when(loading/error/data)`** = menangani ketiga keadaan dalam **satu tempat rapi**,
  menggantikan pola lama `if (_loading) ... else if (_error) ... else ...`.
- **(C) `ref.read(...notifier).refresh()`** = memicu aksi (ambil ulang) tanpa layar tahu
  detail cara ambil datanya. Layar cukup tahu "minta refresh".

### 4c. Kenapa ini lebih baik
- Tampilan **tidak lagi** mengurus cara ambil data / loading / error → layar jadi kecil & jelas.
- Data & logika di **provider** → bisa dipakai ulang di banyak layar, dan **mudah dites**
  (tinggal ganti `customerRepositoryProvider` dengan mock — persis yang dilakukan widget test).
- Loading/error jadi **gratis & seragam** lewat `AsyncValue`.

---

## 5. `ProviderScope` di `main.dart` — "sakelar utama"

`lib/main.dart` (baris ~44):

```dart
runApp(ProviderScope(          // ← membungkus SELURUH aplikasi
  child: MbisApp(
    authRepository: authRepository,
    initialSession: session,
  ),
));
```

- `ProviderScope` = **sakelar utama Riverpod**. Ia wajib ada agar provider mana pun bisa hidup.
- Sifatnya **aditif/transparan**: layar lama yang belum pakai Riverpod **tetap jalan
  normal**; hanya modul yang sudah pakai Riverpod (mis. `customer`) yang teraktifkan.
- Jadi memasang ini **tidak** memaksa harus migrasi semuanya sekaligus — itulah yang
  memungkinkan **migrasi bertahap**.

---

## 6. Catatan jujur soal status modul `customer`

Agar tidak ada salah paham, ini kondisi apa adanya:

1. **Modul `customer` (Riverpod) belum tersambung ke navigasi aplikasi.** Ia berdiri
   sebagai *teladan* dan diuji lewat widget test, **belum** muncul sebagai layar yang
   dibuka user. (Layar nasabah yang benar-benar dipakai user sekarang masih yang lama
   di `lib/presentation/` / `lib/src/customer/`.)
2. **Masih memakai data *mock*.** `customerRepositoryProvider` mengembalikan
   `MockCustomerRepository` (data palsu). Untuk data asli, tinggal diganti ke
   `ApiCustomerRepository` (butuh `ApiClient` + sesi login) — strukturnya sudah disiapkan.
3. Jadi nilainya sekarang = **"bukti pola + cetakan"**, bukan fitur produksi.

---

## 7. Peta jalan migrasi (cara melanjutkan)

Migrasi dilakukan **per modul**, memakai `customer` sebagai cetakan. Untuk tiap fitur
(mis. `pipeline`, `visit`), langkahnya:

1. Buat folder `lib/features/<fitur>/` dengan 3 lapis: `data/`, `domain/`, `presentation/`.
2. Pindahkan logika ambil-data dari layar `setState` ke **repository** (`data/`) +
   **provider/Notifier** (`presentation/providers/`).
3. Ubah layar `StatefulWidget + setState` menjadi `ConsumerWidget + ref.watch`.
4. Ganti `customerRepositoryProvider`-style dari `Mock` ke `Api` saat wiring nyata.
5. Tambah widget test dengan meng-*override* provider memakai mock.
6. Sambungkan layar baru ke router (`go_router`) menggantikan layar lama.

> Skill pendukung di repo umbrella: **`flutter-riverpod-feature`** (scaffold modul
> baru / migrasi layar lama mengikuti struktur `customer/`).

**Prioritas wajar:** dahulukan layar dengan `setState` terbanyak & paling sering dipakai
(lihat tabel §3) — `kelola_master_data`, `add_pipeline`, `add_customer`, `pipeline_detail`.

---

## 8. Ringkasan satu layar

| Pertanyaan | Jawaban |
|---|---|
| Pakai Riverpod? | **Ya, fondasinya** (`flutter_riverpod` + `ProviderScope`) **+ 1 modul teladan** (`customer`). |
| Mayoritas app sekarang? | Masih **`setState`** (505 panggilan, 57 file). |
| Pola target | **Layered** (`data`/`domain`/`presentation`) **+ Riverpod** (`AsyncNotifierProvider` + `ConsumerWidget`). |
| Kenapa belum semua? | Sengaja **bertahap per modul** agar aman (kode lama tetap jalan). |
| Modul teladan sudah dipakai user? | **Belum** — masih mock & belum di-route; berfungsi sebagai cetakan. |
| Langkah berikutnya | Migrasi layar `setState` prioritas tinggi mengikuti cetakan `customer/`. |

---

*Semua angka & kutipan kode diambil langsung dari `MBIS-App/lib/` per 2026-07-22.
Bila kode berubah (mis. modul baru dimigrasi), perbarui dokumen ini.*
