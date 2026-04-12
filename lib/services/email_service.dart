import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // ─── Sender credentials ──────────────────────────────────────
  static const String _senderEmail    = 'shyamala7680@gmail.com';
  static const String _senderPassword = 'gsoucldicintuyiy';

  /// Send the daily report email.
  /// [pdfFile]  – PDF attachment (may be null on web, skip attachment then)
  /// [date]     – formatted date string e.g. "2025-06-01"
  /// [toEmail]  – recipient from ReportSettingsService
  /// [summary]  – { orders, total, cash, online } from DailyScheduler
  /// [items]    – [ { name, qty, revenue } ] product breakdown
  /// [expense]  – total today expenses (₹)
  static Future<void> sendReport(
    File? pdfFile,
    String date,
    String toEmail, {
    Map<String, dynamic>? summary,
    List<Map<String, dynamic>>? items,
    double expense = 0.0,
  }) async {
    final smtpServer = gmail(_senderEmail, _senderPassword);

    final totalSales = (summary?['total'] as num?)?.toDouble() ?? 0.0;
    final cash       = (summary?['cash']  as num?)?.toDouble() ?? 0.0;
    final online     = (summary?['online'] as num?)?.toDouble() ?? 0.0;
    final orders     = (summary?['orders'] as num?)?.toInt()   ?? 0;
    final profit     = totalSales - expense;

    final html = _buildHtml(
      date    : date,
      orders  : orders,
      total   : totalSales,
      cash    : cash,
      online  : online,
      expense : expense,
      profit  : profit,
      items   : items ?? [],
    );

    final message = Message()
      ..from = Address(_senderEmail, '🍽️ FlavorFlow POS')
      ..recipients.add(toEmail)
      ..subject = '📊 Daily Sales Report — $date'
      ..html = html;

    // Attach PDF only on non-web platforms
    if (pdfFile != null && await pdfFile.exists()) {
      message.attachments.add(FileAttachment(pdfFile));
    }

    try {
      await send(message, smtpServer);
      print('✅ Daily report sent to $toEmail');
    } catch (e) {
      print('❌ Email sending failed: $e');
      rethrow;
    }
  }

  // ─── HTML email builder ──────────────────────────────────────
  static String _buildHtml({
    required String date,
    required int    orders,
    required double total,
    required double cash,
    required double online,
    required double expense,
    required double profit,
    required List<Map<String, dynamic>> items,
  }) {
    final profitColor  = profit >= 0 ? '#4ADE80' : '#EF4444';
    final profitLabel  = profit >= 0 ? '✅ Profit' : '⚠️ Loss';
    final cashPct      = total > 0 ? (cash / total * 100).toStringAsFixed(1) : '0.0';
    final onlinePct    = total > 0 ? (online / total * 100).toStringAsFixed(1) : '0.0';

    // Build product rows
    final productRows = items.isEmpty
        ? '<tr><td colspan="3" style="text-align:center;color:#888;padding:20px;">No product data</td></tr>'
        : items.asMap().entries.map((e) {
            final i       = e.key;
            final item    = e.value;
            final name    = item['name']?.toString()    ?? '-';
            final qty     = item['qty']?.toString()     ?? '0';
            final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
            final rowBg   = i % 2 == 0 ? '#1A1A2E' : '#16162A';
            final medal   = i == 0 ? '🥇 ' : i == 1 ? '🥈 ' : i == 2 ? '🥉 ' : '${i + 1}. ';
            return '''
              <tr style="background:$rowBg;">
                <td style="padding:12px 16px;color:#E2E8F0;font-size:13px;">$medal$name</td>
                <td style="padding:12px 16px;color:#94A3B8;text-align:center;font-size:13px;">×$qty</td>
                <td style="padding:12px 16px;color:#FF6A00;font-weight:700;text-align:right;font-size:13px;">₹${revenue.toStringAsFixed(0)}</td>
              </tr>''';
          }).join('\n');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Daily Sales Report</title>
</head>
<body style="margin:0;padding:0;background:#0A0A0F;font-family:'Segoe UI',Arial,sans-serif;">

  <!-- Wrapper -->
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#0A0A0F;padding:32px 0;">
    <tr><td align="center">
    <table width="620" cellpadding="0" cellspacing="0" style="background:#0F1117;border-radius:20px;overflow:hidden;border:1px solid #1E2235;">

      <!-- ── HEADER ────────────────────────────────────────────── -->
      <tr>
        <td style="background:linear-gradient(135deg,#FF6A00 0%,#FF8C00 100%);padding:32px 36px;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td>
                <p style="margin:0;font-size:22px;font-weight:800;color:#fff;letter-spacing:-0.5px;">🍽️ FlavorFlow POS</p>
                <p style="margin:4px 0 0;font-size:13px;color:rgba(255,255,255,0.75);">Daily Sales Summary Report</p>
              </td>
              <td align="right">
                <p style="margin:0;font-size:13px;color:rgba(255,255,255,0.75);">Report Date</p>
                <p style="margin:4px 0 0;font-size:18px;font-weight:800;color:#fff;">$date</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- ── KPI CARDS ─────────────────────────────────────────── -->
      <tr>
        <td style="padding:28px 28px 0;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <!-- Total Sales -->
              <td width="25%" style="padding:4px;">
                <div style="background:#1A1A2E;border-radius:14px;padding:20px 16px;border:1px solid #1E2235;text-align:center;">
                  <p style="margin:0;font-size:22px;">💰</p>
                  <p style="margin:8px 0 4px;font-size:10px;color:#64748B;font-weight:700;letter-spacing:0.5px;text-transform:uppercase;">Total Sales</p>
                  <p style="margin:0;font-size:20px;font-weight:900;color:#4ADE80;">₹${total.toStringAsFixed(0)}</p>
                  <p style="margin:4px 0 0;font-size:11px;color:#64748B;">$orders bills</p>
                </div>
              </td>
              <!-- Cash -->
              <td width="25%" style="padding:4px;">
                <div style="background:#1A1A2E;border-radius:14px;padding:20px 16px;border:1px solid #1E2235;text-align:center;">
                  <p style="margin:0;font-size:22px;">💵</p>
                  <p style="margin:8px 0 4px;font-size:10px;color:#64748B;font-weight:700;letter-spacing:0.5px;text-transform:uppercase;">Cash</p>
                  <p style="margin:0;font-size:20px;font-weight:900;color:#FBBF24;">₹${cash.toStringAsFixed(0)}</p>
                  <p style="margin:4px 0 0;font-size:11px;color:#64748B;">$cashPct% of sales</p>
                </div>
              </td>
              <!-- Online / UPI -->
              <td width="25%" style="padding:4px;">
                <div style="background:#1A1A2E;border-radius:14px;padding:20px 16px;border:1px solid #1E2235;text-align:center;">
                  <p style="margin:0;font-size:22px;">📱</p>
                  <p style="margin:8px 0 4px;font-size:10px;color:#64748B;font-weight:700;letter-spacing:0.5px;text-transform:uppercase;">UPI / Online</p>
                  <p style="margin:0;font-size:20px;font-weight:900;color:#3B82F6;">₹${online.toStringAsFixed(0)}</p>
                  <p style="margin:4px 0 0;font-size:11px;color:#64748B;">$onlinePct% of sales</p>
                </div>
              </td>
              <!-- Net Profit -->
              <td width="25%" style="padding:4px;">
                <div style="background:#1A1A2E;border-radius:14px;padding:20px 16px;border:1px solid #1E2235;text-align:center;">
                  <p style="margin:0;font-size:22px;">📈</p>
                  <p style="margin:8px 0 4px;font-size:10px;color:#64748B;font-weight:700;letter-spacing:0.5px;text-transform:uppercase;">$profitLabel</p>
                  <p style="margin:0;font-size:20px;font-weight:900;color:$profitColor;">₹${profit.abs().toStringAsFixed(0)}</p>
                  <p style="margin:4px 0 0;font-size:11px;color:#64748B;">after ₹${expense.toStringAsFixed(0)} exp</p>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>

      <!-- ── EXPENSE BAR ────────────────────────────────────────── -->
      <tr>
        <td style="padding:20px 32px;">
          <div style="background:#1A1A2E;border-radius:12px;padding:18px 20px;border:1px solid #1E2235;">
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td><p style="margin:0;font-size:13px;color:#94A3B8;font-weight:600;">💸 Today's Expenses</p></td>
                <td align="right"><p style="margin:0;font-size:16px;font-weight:800;color:#EF4444;">- ₹${expense.toStringAsFixed(2)}</p></td>
              </tr>
              <tr>
                <td colspan="2" style="padding-top:10px;">
                  <div style="background:#0A0A0F;border-radius:6px;height:8px;overflow:hidden;">
                    <div style="background:#EF4444;height:8px;border-radius:6px;width:${total > 0 ? (expense / total * 100).clamp(0, 100).toStringAsFixed(1) : 0}%;"></div>
                  </div>
                </td>
              </tr>
            </table>
          </div>
        </td>
      </tr>

      <!-- ── PRODUCT TABLE ──────────────────────────────────────── -->
      <tr>
        <td style="padding:0 32px 28px;">
          <p style="margin:0 0 14px;font-size:15px;font-weight:800;color:#E2E8F0;">🏆 Product Sales Breakdown</p>
          <table width="100%" cellpadding="0" cellspacing="0" style="border-radius:12px;overflow:hidden;border:1px solid #1E2235;">
            <!-- Header -->
            <tr style="background:#FF6A00;">
              <th style="padding:12px 16px;text-align:left;font-size:11px;color:#fff;font-weight:800;letter-spacing:0.5px;">PRODUCT</th>
              <th style="padding:12px 16px;text-align:center;font-size:11px;color:#fff;font-weight:800;letter-spacing:0.5px;">QTY SOLD</th>
              <th style="padding:12px 16px;text-align:right;font-size:11px;color:#fff;font-weight:800;letter-spacing:0.5px;">REVENUE</th>
            </tr>
            $productRows
          </table>
        </td>
      </tr>

      <!-- ── DIVIDER ────────────────────────────────────────────── -->
      <tr><td style="padding:0 32px;"><hr style="border:none;border-top:1px solid #1E2235;margin:0;"></td></tr>

      <!-- ── FOOTER ─────────────────────────────────────────────── -->
      <tr>
        <td style="padding:24px 32px;text-align:center;">
          <p style="margin:0;font-size:12px;color:#334155;">
            Auto-generated by <strong style="color:#FF6A00;">FlavorFlow POS</strong> · $date
          </p>
          <p style="margin:6px 0 0;font-size:11px;color:#1E3A5F;">
            This is an automated daily report. Do not reply to this email.
          </p>
        </td>
      </tr>

    </table>
    </td></tr>
  </table>

</body>
</html>''';
  }
}
