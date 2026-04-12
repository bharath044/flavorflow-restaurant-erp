import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class DailyReportPdf {
  static Future<File> generate({
    required Map<String, dynamic> summary,
    required File pieChart,
    required File barChart,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Daily Sales Report',
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold)),

          pw.Text('Date: ${summary['date']}'),
          pw.SizedBox(height: 10),

          pw.Text('Total Orders: ${summary['orders']}'),
          pw.Text('Total Sales: ₹${summary['total']}'),

          pw.SizedBox(height: 20),
          pw.Text('Hourly Sales'),
          pw.Image(pw.MemoryImage(barChart.readAsBytesSync()), height: 200),

          pw.SizedBox(height: 20),
          pw.Text('Payment Split'),
          pw.Image(pw.MemoryImage(pieChart.readAsBytesSync()), height: 200),

          pw.SizedBox(height: 20),
          pw.Text('Item-wise Sales'),

          pw.Table.fromTextArray(
            headers: ['Item', 'Qty', 'Total'],
            data: items
                .map((e) => [
                      e['item_name'],
                      e['qty'].toString(),
                      '₹${e['total']}'
                    ])
                .toList(),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file =
        File('${dir.path}/Daily_Report_${summary['date']}.pdf');

    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
