import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/note_model.dart';

class ExportService {
  // ── PDF Export ──────────────────────────────────
  Future<File> exportToPdf(
    NoteModel note, {
    required bool includeSummary,
    required bool includeTranscript,
    required bool includeKeywords,
    required bool includeMeta,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Note Lingo',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
              pw.Text(
                DateFormat('MMM dd, yyyy').format(note.createdAt),
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Title
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.31, 0.27, 0.90),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              note.title,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          // Meta
          if (includeMeta) ...[
            pw.Row(
              children: [
                _pdfBadge('Category: ${note.categoryLabel}'),
                pw.SizedBox(width: 8),
                _pdfBadge('Language: ${note.languageLabel}'),
                pw.SizedBox(width: 8),
                _pdfBadge('${note.wordCount} words'),
                pw.SizedBox(width: 8),
                _pdfBadge(note.formattedDuration),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          // Keywords
          if (includeKeywords && note.keywords.isNotEmpty) ...[
            _pdfSectionTitle('Keywords'),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: note.keywords.map((k) => _pdfBadge('#$k')).toList(),
            ),
            pw.SizedBox(height: 16),
          ],
          // Summary
          if (includeSummary && note.summary.isNotEmpty) ...[
            _pdfSectionTitle('AI Summary'),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor(0.94, 0.97, 1.0),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                note.summary,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          // Transcript
          if (includeTranscript && note.transcription.isNotEmpty) ...[
            _pdfSectionTitle('Full Transcript'),
            pw.Text(
              note.transcription,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
            ),
          ],
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${note.title.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfBadge(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  // ── DOCX Export ─────────────────────────────────
  // For DOCX we generate an RTF-compatible .docx using basic structure
  // For full DOCX support add 'docx' package or use 'dart_docx'
  Future<File> exportToDocx(
    NoteModel note, {
    required bool includeSummary,
    required bool includeTranscript,
    required bool includeKeywords,
  }) async {
    // Build RTF content (compatible with Word)
    final buffer = StringBuffer();
    buffer.writeln('{\\rtf1\\ansi\\deff0');
    buffer.writeln('{\\fonttbl{\\f0 Arial;}}');
    buffer.writeln('\\f0\\fs28\\b ${_rtfEscape(note.title)}\\b0\\fs24\\par');
    buffer.writeln('\\par');

    if (includeMeta_) {
      buffer.writeln(
        'Category: ${note.categoryLabel} | Language: ${note.languageLabel} | ${note.wordCount} words\\par\\par',
      );
    }

    if (includeKeywords && note.keywords.isNotEmpty) {
      buffer.writeln('\\b Keywords:\\b0\\par');
      buffer.writeln(note.keywords.map((k) => '#$k').join(', '));
      buffer.writeln('\\par\\par');
    }

    if (includeSummary && note.summary.isNotEmpty) {
      buffer.writeln('\\b AI Summary:\\b0\\par');
      buffer.writeln(_rtfEscape(note.summary));
      buffer.writeln('\\par\\par');
    }

    if (includeTranscript && note.transcription.isNotEmpty) {
      buffer.writeln('\\b Full Transcript:\\b0\\par');
      buffer.writeln(_rtfEscape(note.transcription));
      buffer.writeln('\\par');
    }

    buffer.writeln('}');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${note.title.replaceAll(' ', '_')}.rtf');
    await file.writeAsString(buffer.toString());
    return file;
  }

  // Flag to avoid undefined variable - set to true by default for docx
  final bool includeMeta_ = true;

  String _rtfEscape(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('{', '\\{')
        .replaceAll('}', '\\}')
        .replaceAll('\n', '\\par ');
  }

  // ── TXT Export ──────────────────────────────────
  Future<File> exportToTxt(
    NoteModel note, {
    required bool includeSummary,
    required bool includeTranscript,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('  NOTE LINGO — ${note.title.toUpperCase()}');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Category : ${note.categoryLabel}');
    buffer.writeln('Language : ${note.languageLabel}');
    buffer.writeln(
      'Date     : ${DateFormat('MMM dd, yyyy').format(note.createdAt)}',
    );
    buffer.writeln('Duration : ${note.formattedDuration}');
    buffer.writeln('Words    : ${note.wordCount}');
    buffer.writeln('');

    if (note.keywords.isNotEmpty) {
      buffer.writeln('── KEYWORDS ──────────────────────────────');
      buffer.writeln(note.keywords.map((k) => '#$k').join('  '));
      buffer.writeln('');
    }

    if (includeSummary && note.summary.isNotEmpty) {
      buffer.writeln('── AI SUMMARY ────────────────────────────');
      buffer.writeln(note.summary);
      buffer.writeln('');
    }

    if (includeTranscript && note.transcription.isNotEmpty) {
      buffer.writeln('── FULL TRANSCRIPT ───────────────────────');
      buffer.writeln(note.transcription);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${note.title.replaceAll(' ', '_')}.txt');
    await file.writeAsString(buffer.toString());
    return file;
  }
}
