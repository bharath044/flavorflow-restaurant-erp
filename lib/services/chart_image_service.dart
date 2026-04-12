import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ChartImageService {
  static Future<File> generatePaymentPie({
    required double cash,
    required double online,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paintCash = Paint()..color = Colors.green;
    final paintOnline = Paint()..color = Colors.blue;

    const radius = 120.0;
    const center = Offset(150, 150);

    final total = cash + online;
    final cashAngle = (cash / total) * 3.14159 * 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      cashAngle,
      true,
      paintCash,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      cashAngle,
      3.14159 * 2 - cashAngle,
      true,
      paintOnline,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 300);
    final bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/payment_pie.png');

    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }
}
