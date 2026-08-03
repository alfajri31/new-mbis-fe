# Bug: Realisasi kartu analisis Customer selalu 0 / strip di produksi

**Status:** Akar masalah teridentifikasi — **bukan bug kode, melainkan gap deploy.**
**Ditemukan:** 3 Agustus 2026 (diverifikasi langsung ke prod dari luar jaringan kantor).
**Dampak:** Kartu Target/Realisasi di layar **Customer → analisis** menampilkan
Realisasi `0` / `–` dan progress bar kosong, di **semua role** dan **semua filter**.
**Perbaikan:** Deploy ulang backend prod dari sumber terkini. **Tidak ada kode yang perlu diubah.**

---

## 1. Gejala yang dilaporkan

> "Di fungsi analisis, bagian Customer, ada Target yang ikut berubah jika difilter.
> Tapi Realisasinya tidak nambah — progress bar-nya tidak bergerak. Padahal di
> dashboard sudah benar, sudah nambah."

Rincian dari pelapor:

- Realisasi tampil **0 / strip**, sementara Target/filter tampak berubah.
- Terjadi saat mengubah filter apa pun (COB, Wilayah/Cabang, RM).
- Diuji sebagai **ADMIN**, tetapi diharapkan sama untuk semua role.

## 2. Akar masalah

Kartu Target/Realisasi di layar Customer mengambil angkanya dari **satu** endpoint:

```
GET /api/dashboard/customer-summary
```

**Endpoint ini tidak ada di backend produksi yang sedang berjalan** — ia membalas
`404 Not Found`. Semua endpoint dashboard baru lainnya sudah ter-deploy dan
membalas `200`. Yang tertinggal hanya `customer-summary`.

Artinya frontend prod **lebih baru** daripada backend prod: aplikasi web sudah
memuat kartu ini dan memanggil endpoint-nya, tetapi backend yang ter-deploy
dibangun dari commit **sebelum** endpoint tersebut masuk.

## 3. Bukti

Diambil 3 Agustus 2026 dari `https://mbis.askrindo.co.id/v2` (jalur publik,
sertifikat sah), dengan token login sah untuk dua role berbeda.

| Endpoint | Prod (ADMIN) | Prod (RM) |
|---|---|---|
| `GET /api/dashboard/summary` | **200** — realisasi terisi (mis. 55.745.600) | **200** — realisasi terisi (mis. 50.545.600) |
| `GET /api/dashboard/categories` | 200 | 200 |
| `GET /api/dashboard/rm-options` | 200 | 200 |
| `GET /api/dashboard/scope-offices` | 200 | 200 |
| `GET /api/dashboard/rm-performance` | 200 | 200 |
| **`GET /api/dashboard/customer-summary`** | **404** | **404** |
| **`GET /api/dashboard/customer-summary?cob=ASUM`** | **404** | **404** |

Perintah reproduksi (ganti `<TOKEN>` dengan access token login yang sah):

```bash
BASE=https://mbis.askrindo.co.id/v2
TOKEN=<TOKEN>

# 404 di prod — inilah bug-nya
curl -s "$BASE/api/dashboard/customer-summary" -H "Authorization: Bearer $TOKEN"

# 200 di prod — endpoint dashboard bekerja, realisasi terisi
curl -s "$BASE/api/dashboard/summary" -H "Authorization: Bearer $TOKEN"
```

> Catatan jaringan: dari **dalam** jaringan kantor, `mbis.askrindo.co.id`
> diresolusi ke DNS internal (`10.10.1.242`) dengan CA internal, sehingga `curl`
> gagal `SEC_E_UNTRUSTED_ROOT` dan perlu `-k`. Dari **luar** jaringan kantor
> (hotspot seluler) ia menuju IP publik `9.154.64.93` dengan sertifikat Sectigo
> yang sah. Verifikasi harus dari luar jaringan kantor.

## 4. Kenapa gejalanya persis seperti itu

Kartu memuat datanya di `_loadSummary()`
([`lib/presentation/providers/customer_list_provider.dart`](../lib/presentation/providers/customer_list_provider.dart)):

```dart
Future<void> _loadSummary() async {
  if (!state.isSupervisor) return;
  try {
    final s = await _dashRepo.getCustomerSummary(
      regionId: state.regionId, branchId: state.branchId,
      rmId: state.rmId, cob: state.cob,
    );
    state = state.copyWith(summary: s);
  } catch (_) {
    // Kartu dekoratif; biarkan "–" bila gagal.   ← 404 ditelan diam-diam
  }
}
```

- Panggilan `customer-summary` membalas **404** → masuk `catch` → `summary` tetap
  `null` → kartu menampilkan **Realisasi 0 / strip**, bar kosong.
- **Dropdown COB tetap berubah** karena opsinya berasal dari `getCategories()`
  (`/api/dashboard/categories`, yang **200**), bukan dari `customer-summary`.

Inilah kenapa "filter/target tampak berubah tapi realisasi tidak nambah": kedua
bagian kartu memakai sumber data berbeda, dan hanya salah satunya yang ter-deploy.

## 5. Kenapa ini BUKAN bug kode

- Kode fitur ini **identik** di keempat repo (`fe-new-mbis`, `MBIS-Frontend`,
  `be-new-mbis`, `be-new-mbis`) — dibandingkan baris demi baris.
- Endpoint-nya **ada di sumber** backend prod:
  [`be-new-mbis/.../controller/DashboardController.java`](../../be-new-mbis/src/main/java/com/askrindo/mbis/controller/DashboardController.java)
  (`@GetMapping("/customer-summary")`).
- Di **backend lokal** yang dibangun dari sumber ini, `customer-summary` bekerja
  dan Realisasi **ikut berubah** di semua filter (COB, wilayah, cabang, RM).

Jadi mengubah kode di sini justru berisiko merusak dashboard yang sudah benar.
Yang tertinggal adalah **artefak deploy**, bukan sumbernya.

## 6. Perbaikan

**Deploy ulang backend produksi dari sumber `be-new-mbis` terkini.** Ini menutup
gap tanpa perubahan kode. Selaras dengan catatan bahwa sinkronisasi prod lewat
branch `feat/synchronization` masih menunggu PR/deploy.

Setelah deploy, verifikasi (dari luar jaringan kantor, dengan token sah):

```bash
# Harus 200 dan berisi angka, bukan 404
curl -s https://mbis.askrindo.co.id/v2/api/dashboard/customer-summary \
  -H "Authorization: Bearer <TOKEN>"

# Tanpa filter, realisasi customer-summary HARUS sama dengan
# totalRealization di /summary untuk role & waktu yang sama.
```

## 7. Yang BELUM terverifikasi

- **Staging (`mbis.askrindo.net`).** Kredensial yang tersedia hanya berlaku di
  prod, jadi belum bisa dipastikan apakah staging juga tertinggal. Perlu token
  staging untuk mengeceknya dengan cara yang sama.
- **Endpoint lain.** Karena gap-nya di tingkat build, ada kemungkinan endpoint
  lain juga tertinggal. Saat deploy ulang, sebaiknya cek daftar endpoint dashboard
  di §3 seluruhnya kembali `200`, bukan hanya `customer-summary`.

## 8. Perbaikan pendukung yang disarankan (opsional, di kode)

Kartu ini gagal **sunyi** (`catch (_)`), sehingga endpoint yang hilang tampak
seperti "realisasi 0" — menyamar sebagai bug data dan menyulitkan diagnosis
seperti kali ini. Disarankan menampilkan status **"gagal memuat"** yang eksplisit
di kartu ketika `customer-summary` error, agar masalah deploy tidak lagi menyaru
sebagai angka nol. Ini perubahan kecil dan aman, tidak menyentuh perhitungan
realisasi mana pun.

---

**Ringkas:** Frontend prod memanggil `customer-summary`; backend prod belum
punya endpoint itu (404); frontend menelan errornya diam-diam dan menampilkan
Realisasi 0. Perbaikannya deploy ulang backend, bukan edit kode.
