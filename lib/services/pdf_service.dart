import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> printBill(String billNo, double total) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          children: [
            pw.Text("Restaurant Billing"),
            pw.Text("Bill No: $billNo"),
            pw.Text("Total: ₹$total"),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}
