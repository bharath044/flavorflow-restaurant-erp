enum PaymentMode { cash, online }

extension PaymentModeX on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.cash:
        return "CASH";
      case PaymentMode.online:
        return "ONLINE";
    }
  }
}
