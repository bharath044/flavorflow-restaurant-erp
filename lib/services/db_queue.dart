import 'package:synchronized/synchronized.dart';

class DbQueue {
  static final Lock _lock = Lock();

  static Future<T> run<T>(Future<T> Function() action) async {
    return await _lock.synchronized(action);
  }
}
