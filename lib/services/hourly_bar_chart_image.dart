import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class HourlyBarChartImage {
  static Future<File> generate(Map<int, double> data) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final barPaint = Paint()..color = Colors.orange;
    const width = 500.0;
    const height = 250.0;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final max = data.values.fold<double>(0, (a, b) => b > a ? b : a);
    const barWidth = 14.0;
    int i = 0;

    data.forEach((hour, value) {
      final h = (value / max) * 180;
      canvas.drawRect(
        Rect.fromLTWH(
          30 + i * 18,
          200 - h,
          barWidth,
          h,
        ),
        barPaint,
      );
      i++;
    });

    final image = await recorder
        .endRecording()
        .toImage(width.toInt(), height.toInt());

    final bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/hourly_bar.png');

    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }
}
