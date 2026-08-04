# Laporan: dua masalah sertifikat TLS pada `mbis.askrindo.co.id`

**Tanggal:** 4 Agustus 2026
**Untuk:** tim infrastruktur / pengelola reverse proxy & FortiWeb
**Dampak:** aplikasi Android M-BIS **tidak bisa dipakai dari jaringan kantor**, dan
seluruh klien non-browser (curl, Postman, integrasi Java) gagal di jaringan publik.

Keduanya masalah **konfigurasi server**. Tidak ada perubahan di sisi aplikasi yang
bisa memperbaikinya, dan tidak perlu rilis aplikasi baru setelah diperbaiki.

---

## Masalah 1 — jalur publik mengirim sertifikat leaf saja

Dari internet (`9.154.64.93`), server hanya mengirim **satu** sertifikat. Sertifikat
antara (*intermediate*) **Sectigo Public Server Authentication CA DV R36** tidak
disertakan, sehingga rantai kepercayaan terputus.

```
$ openssl s_client -servername mbis.askrindo.co.id \
    -connect mbis.askrindo.co.id:443 -showcerts </dev/null

 0 s:CN=askrindo.co.id
   i:C=GB, O=Sectigo Limited, CN=Sectigo Public Server Authentication CA DV R36
                                    ^^^ penerbit ini TIDAK ikut dikirim
Verify return code: 21 (unable to verify the first certificate)
```

Jumlah sertifikat yang dikirim: **1**. Seharusnya minimal **2** (leaf + R36).

Sebagai pembanding, staging `mbis.askrindo.net` sudah benar — mengirim 3 sertifikat,
`Verify return code: 0 (ok)`.

### Kenapa browser terlihat baik-baik saja

Browser menambal rantai yang putus sendiri lewat **AIA fetching**: alamat penerbit
tertanam di dalam sertifikat leaf, dan browser mengunduhnya diam-diam. Klien lain
tidak melakukan itu — termasuk Android/Flutter, curl, Postman, dan pustaka Java.
Karena itu gejalanya menyesatkan: **web tampak sehat, aplikasi gagal**.

### Perbaikan

Arahkan `ssl_certificate` (nginx) atau berkas sertifikat pada proxy ke berkas
**fullchain**, bukan leaf saja:

```
fullchain.pem  =  sertifikat leaf  +  Sectigo R36
```

Berkas intermediate resmi dapat diunduh dari:
`http://crt.sectigo.com/SectigoPublicServerAuthenticationCADVR36.crt`

---

## Masalah 2 — jalur internal memakai sertifikat pabrikan FortiWeb

Dari dalam jaringan kantor, DNS internal mengarahkan domain ke `10.10.1.242`, dan
host itu menyajikan **sertifikat bawaan pabrik Fortinet yang self-signed**:

```
$ nslookup mbis.askrindo.co.id
Address: 10.10.1.242

$ openssl s_client -servername mbis.askrindo.co.id -connect 10.10.1.242:443
depth=0 C=CA, ST=BC, L=Vancouver, O=Fortinet Inc., OU=Fortinet,
        CN=FortiWEB, emailAddress=support@fortinet.com
verify error:num=18:self-signed certificate
NotBefore: Jan 30 2023 -- NotAfter: Dec 31 2056
```

Layanannya sendiri **sudah benar** — proxy meneruskan ke aplikasi dengan baik:

```
/v2/actuator/health -> 200  {"status":"UP","groups":["liveness","readiness"]}
/app/               -> 200
```

Jadi yang salah **hanya sertifikat yang terpasang pada listener**, bukan routing-nya.

### Dampak yang sudah terbukti

Diuji pada perangkat Android nyata, 4 Agustus 2026, dengan aplikasi rilis:

| Jaringan | Hasil |
|---|---|
| Kuota seluler (jalur publik) | login **berhasil**, unggah dokumen berhasil |
| WiFi kantor (jalur `10.10.1.242`) | login **gagal** |

Sertifikat self-signed pabrikan tidak dipercaya oleh trust store mana pun. Browser
masih bisa dilanjutkan pengguna dengan menekan "lanjutkan saja"; **aplikasi tidak
punya tombol itu** dan wajib menolak koneksi.

Artinya seluruh pengguna M-BIS di kantor tidak akan bisa memakai aplikasi sama
sekali, sementara laporan yang masuk akan berbunyi "aplikasinya rusak".

### Perbaikan

Pasang sertifikat Sectigo yang sama (**fullchain**: leaf + R36) pada virtual server
FortiWeb yang melayani `mbis.askrindo.co.id`, menggantikan sertifikat pabrikan.

---

## Cara memverifikasi setelah diperbaiki

Jalankan dari **luar** jaringan kantor dan dari **dalam**, keduanya harus lulus:

```bash
# 1. Rantai lengkap & tepercaya — harus "Verify return code: 0 (ok)"
openssl s_client -servername mbis.askrindo.co.id \
  -connect mbis.askrindo.co.id:443 </dev/null 2>/dev/null | grep "Verify return code"

# 2. Jumlah sertifikat yang dikirim — harus 2 atau lebih, bukan 1
openssl s_client -servername mbis.askrindo.co.id \
  -connect mbis.askrindo.co.id:443 -showcerts </dev/null 2>/dev/null \
  | grep -c "BEGIN CERTIFICATE"

# 3. Uji tanpa -k. Kalau perlu -k, berarti belum beres.
curl https://mbis.askrindo.co.id/v2/actuator/health
```

Verifikasi **wajib dilakukan dari kedua sisi jaringan**. Domain ini memakai
split-horizon DNS (`10.10.1.242` dari kantor, `9.154.64.93` dari internet), jadi
pengujian dari satu sisi saja akan menyembunyikan separuh masalahnya.

---

## Catatan masa berlaku

Sertifikat wildcard `*.askrindo.co.id` yang dipakai sekarang berlaku sampai
**10 April 2027**. Ini sertifikat korporat, **bukan** Let's Encrypt — tidak
memperbarui diri sendiri. Saat kedaluwarsa, API dan web mati bersamaan.
Jadwalkan perpanjangan jauh sebelum tanggal tersebut.
