import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data untuk satu proforma invoice / estimasi premi dari Kalkulator Premi.
class PremiInvoiceData {
  final String invoiceNo;
  final DateTime date;

  // Penerbit (RM).
  final String rmName;
  final String rmNip;
  final String? officeBranchName;
  final String? officeRegionalName;

  // Nasabah.
  final String customerName;
  final String? customerCategory;

  // Produk (COB → LOB → ToC seperti pipeline).
  final String cob;
  final String lob;
  final String toc;
  final String? riskTier; // High/Low/Normal untuk CAR & MB, null jika tak ada.

  // Perhitungan.
  final String currency;
  final num tsiOriginal;
  final double kurs;
  final num tsiIdr;
  final double ratePercent;
  final num diskonPercent;
  final bool minPremiApplied;
  final num premi;

  /// Biaya admin nominal di luar premi (CR-21); 0 = dokumen tampil seperti
  /// sebelumnya, tanpa baris biaya admin.
  final num biayaAdmin;

  /// Yang ditagihkan: [premi] + [biayaAdmin].
  num get totalTagihan => premi + biayaAdmin;

  const PremiInvoiceData({
    required this.invoiceNo,
    required this.date,
    required this.rmName,
    required this.rmNip,
    required this.officeBranchName,
    required this.officeRegionalName,
    required this.customerName,
    required this.customerCategory,
    required this.cob,
    required this.lob,
    required this.toc,
    required this.riskTier,
    required this.currency,
    required this.tsiOriginal,
    required this.kurs,
    required this.tsiIdr,
    required this.ratePercent,
    required this.diskonPercent,
    required this.minPremiApplied,
    required this.premi,
    this.biayaAdmin = 0,
  });
}

// Brand colors.
const _navy = PdfColor.fromInt(0xFF0D2C54);
const _orange = PdfColor.fromInt(0xFFF2843A);
const _muted = PdfColor.fromInt(0xFF64748B);
const _line = PdfColor.fromInt(0xFFE2E8F0);
const _rowAlt = PdfColor.fromInt(0xFFF8FAFC);

/// Builds a single-page A4 proforma-invoice PDF and returns its bytes.
Future<Uint8List> buildPremiInvoicePdf(PremiInvoiceData d) async {
  final logoData = await rootBundle.load('assets/images/askrindo-logo.png');
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(d, logo),
          pw.SizedBox(height: 18),
          _parties(d),
          pw.SizedBox(height: 18),
          _lineItems(d),
          pw.SizedBox(height: 12),
          _totals(d),
          pw.Spacer(),
          _footer(d),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _header(PremiInvoiceData d, pw.MemoryImage logo) {
  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Image(logo, height: 46),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'OFFERING LETTER',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.Text(
                'Estimasi Premi',
                style: const pw.TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: const pw.BoxDecoration(
          color: _rowAlt,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Flexible(child: _kv('No. Dokumen', d.invoiceNo)),
            pw.SizedBox(width: 12),
            pw.Flexible(child: _kv('Tanggal', _fmtDate(d.date), alignEnd: true)),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _parties(PremiInvoiceData d) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _partyBox('Kepada (Calon Tertanggung)', [
          d.customerName,
          if (d.customerCategory != null && d.customerCategory!.isNotEmpty)
            d.customerCategory!,
        ]),
      ),
      pw.SizedBox(width: 14),
      pw.Expanded(child: _rmBox(d)),
    ],
  );
}

/// RM issuer box. Office identity is listed above the RM name (Kantor Wilayah → Kantor Cabang →
/// Nama RM), while the RM name stays the visually emphasized line via [primaryIndex].
pw.Widget _rmBox(PremiInvoiceData d) {
  final hasRegional =
      d.officeRegionalName != null && d.officeRegionalName!.isNotEmpty;
  final hasBranch =
      d.officeBranchName != null && d.officeBranchName!.isNotEmpty;
  final lines = <String>[
    if (hasRegional) 'Kantor Wilayah: ${d.officeRegionalName}',
    if (hasBranch) 'Kantor Cabang: ${d.officeBranchName}',
    d.rmName,
    if (d.rmNip.isNotEmpty) 'NIP: ${d.rmNip}',
    'PT Asuransi Kredit Indonesia (Askrindo)',
  ];
  // The RM name sits right after the office lines.
  final primaryIndex = (hasRegional ? 1 : 0) + (hasBranch ? 1 : 0);
  return _partyBox('Diterbitkan oleh (RM)', lines, primaryIndex: primaryIndex);
}

pw.Widget _partyBox(String title, List<String> lines, {int primaryIndex = 0}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: 6),
        for (var i = 0; i < lines.length; i++)
          pw.Text(
            lines[i],
            style: pw.TextStyle(
              fontSize: i == primaryIndex ? 12 : 9.5,
              fontWeight: i == primaryIndex
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
              color: i == primaryIndex ? _navy : _muted,
            ),
          ),
      ],
    ),
  );
}

pw.Widget _lineItems(PremiInvoiceData d) {
  final toc = d.riskTier != null ? '${d.toc} (${d.riskTier})' : d.toc;
  return pw.Table(
    border: pw.TableBorder.all(color: _line),
    // TSI column is a touch wider now that the original-currency TSI lives there.
    columnWidths: const {
      0: pw.FlexColumnWidth(4.4),
      1: pw.FlexColumnWidth(2.9),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(2.5),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          _th('Deskripsi Produk'),
          _th('TSI/Plafond/Nilai Penjaminan (IDR)', alignEnd: true),
          _th('Rate', alignEnd: true),
          _th('Estimasi Premi (IDR)', alignEnd: true),
        ],
      ),
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  toc,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'COB: ${d.cob}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
                pw.Text(
                  'LOB: ${d.lob}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
                pw.Text(
                  'ToC: ${d.toc}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
              ],
            ),
          ),
          _tsiCell(d),
          _td('${_trim(d.ratePercent)}%', alignEnd: true),
          _td(_num(d.premi), alignEnd: true, bold: true),
        ],
      ),
    ],
  );
}

/// TSI column cell: the IDR value on top and, for non-IDR deals, the original-currency TSI +
/// kurs underneath (moved here from the product description). All lines scale down to fit.
pw.Widget _tsiCell(PremiInvoiceData d) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            _num(d.tsiIdr),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        if (d.currency != 'IDR') ...[
          pw.SizedBox(height: 3),
          pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TSI Asli: ${d.currency} ${_num(d.tsiOriginal)}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Kurs: ${_num(d.kurs)}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
        ],
      ],
    ),
  );
}

pw.Widget _totals(PremiInvoiceData d) {
  final bruto = d.tsiIdr * (d.ratePercent / 100);
  final diskonAmt = bruto * (d.diskonPercent / 100);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Container(
        width: 250,
        child: pw.Column(
          children: [
            _totalRow('Estimasi Premi Bruto', _rp(bruto)),
            if (d.diskonPercent > 0)
              _totalRow(
                'Diskon (${_trim(d.diskonPercent)}%)',
                '- ${_rp(diskonAmt)}',
              ),
            if (d.minPremiApplied)
              _totalRow('Penyesuaian minimum estimasi premi', _rp(d.premi)),
            // CR-21: biaya admin ditambahkan SETELAH premi final (termasuk setelah
            // penyesuaian minimum), jadi dokumen memperlihatkan preminya sendiri
            // dulu baru biayanya — bukan satu angka gabungan yang tak bisa diurai.
            if (d.biayaAdmin > 0) ...[
              _totalRow('Estimasi Premi', _rp(d.premi)),
              _totalRow('Biaya Admin', _rp(d.biayaAdmin)),
            ],
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 10,
              ),
              decoration: const pw.BoxDecoration(
                color: _navy,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      d.biayaAdmin > 0
                          ? 'TOTAL ESTIMASI PREMI + BIAYA ADMIN'
                          : 'TOTAL ESTIMASI PREMI',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Flexible(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        _rp(d.totalTagihan),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _orange,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _footer(PremiInvoiceData d) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Divider(color: _line),
      pw.Text(
        'Dokumen ini adalah ESTIMASI PREMI yang bersifat indikatif dan bukan penawaran '
        'resmi maupun tagihan. Rate final dan syarat pertanggungan mengikuti hasil '
        'underwriting PT Askrindo. Rate mata uang non-IDR bersifat indikatif (referensi ECB).',
        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Dibuat otomatis oleh M-BIS ${_fmtDateTime(d.date)}',
        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
      ),
    ],
  );
}

// ── small helpers ────────────────────────────────────────────────────────────

pw.Widget _kv(String k, String v, {bool alignEnd = false}) {
  return pw.Column(
    crossAxisAlignment: alignEnd
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        k.toUpperCase(),
        style: pw.TextStyle(fontSize: 7, color: _muted, letterSpacing: 0.4),
      ),
      pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          v,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _th(String t, {bool alignEnd = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
  child: pw.Text(
    t,
    textAlign: alignEnd ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
  ),
);

pw.Widget _td(String t, {bool alignEnd = false, bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      // scaleDown keeps long numbers on one line, shrinking instead of overflowing the cell.
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: alignEnd
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          t,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? _navy : PdfColors.black,
          ),
        ),
      ),
    );

pw.Widget _totalRow(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 10),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9.5, color: _muted),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Flexible(
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
        ),
      ),
    ],
  ),
);

String _rp(num v) => 'Rp ${_num(v)}';

String _num(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String _trim(num v) {
  var s = v.toStringAsFixed(4);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

const _months = [
  '',
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month]} ${d.year}';

String _fmtDateTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_fmtDate(d)}, $hh:$mm';
}
