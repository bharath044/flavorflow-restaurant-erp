import 'package:flutter/material.dart';
import '../services/report_settings_service.dart';
import '../services/daily_scheduler.dart';

class AdminReportSettingsScreen extends StatefulWidget {
  const AdminReportSettingsScreen({super.key});

  @override
  State<AdminReportSettingsScreen> createState() =>
      _AdminReportSettingsScreenState();
}

class _AdminReportSettingsScreenState
    extends State<AdminReportSettingsScreen> {
  // ── Design tokens ──────────────────────────────────────────────
  static const Color _kBg      = Color(0xFF0F1117);
  static const Color _kCard    = Color(0xFF1A1A2E);
  static const Color _kOrange  = Color(0xFFFF6A00);
  static const Color _kDivider = Color(0xFF1E2235);

  late TextEditingController _emailCtrl;
  int  _hour   = ReportSettingsService.hour;
  int  _minute = ReportSettingsService.minute;

  bool _saving  = false;
  bool _sending = false;
  String? _statusMsg;
  bool    _isError = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: ReportSettingsService.email);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ReportSettingsService.save(
      email : _emailCtrl.text.trim(),
      hour  : _hour,
      minute: _minute,
    );
    setState(() {
      _saving    = false;
      _statusMsg = '✅ Settings saved! Report will be sent at ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')} daily.';
      _isError   = false;
    });
  }

  Future<void> _sendNow() async {
    if (_sending) return;
    setState(() {
      _sending   = true;
      _statusMsg = null;
    });

    // Save latest email setting first
    await ReportSettingsService.save(
      email : _emailCtrl.text.trim(),
      hour  : _hour,
      minute: _minute,
    );

    try {
      await DailyScheduler.runNow();
      setState(() {
        _statusMsg = '📧 Report sent to ${_emailCtrl.text.trim()}';
        _isError   = false;
      });
    } catch (e) {
      setState(() {
        _statusMsg = '❌ Failed: $e';
        _isError   = true;
      });
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daily Report Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: _kDivider, height: 1, thickness: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Info banner ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kOrange.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: _kOrange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The daily report includes total sales, cash/UPI split, product-wise qty & revenue, expenses, and net profit.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Email field ──────────────────────────────────
                _sectionLabel('RECIPIENT EMAIL'),
                const SizedBox(height: 8),
                _darkField(
                  controller: _emailCtrl,
                  hint     : 'owner@gmail.com',
                  icon     : Icons.email_rounded,
                  keyboard : TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),

                // ── Schedule time ────────────────────────────────
                _sectionLabel('SEND TIME (24-HOUR)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _darkDropdown(
                      label  : 'Hour',
                      value  : _hour,
                      items  : List.generate(24, (i) => i),
                      display: (v) => '${v.toString().padLeft(2, '0')}:00',
                      onChanged: (v) => setState(() => _hour = v!),
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _darkDropdown(
                      label  : 'Minute',
                      value  : _minute,
                      items  : [0, 15, 30, 45],
                      display: (v) => v.toString().padLeft(2, '0'),
                      onChanged: (v) => setState(() => _minute = v!),
                    )),
                  ],
                ),

                // ── Scheduled time preview ───────────────────────
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kDivider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        'Report will send daily at  ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Status message ───────────────────────────────
                if (_statusMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_isError ? Colors.red : Colors.green).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_isError ? Colors.red : const Color(0xFF4ADE80)).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          color: _isError ? Colors.redAccent : const Color(0xFF4ADE80),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMsg!,
                            style: TextStyle(
                              color: _isError ? Colors.redAccent : const Color(0xFF4ADE80),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Buttons ──────────────────────────────────────
                Row(
                  children: [
                    // Save Settings
                    Expanded(
                      child: _ActionButton(
                        label   : _saving ? 'Saving…' : 'Save Settings',
                        icon    : _saving ? null : Icons.save_rounded,
                        color   : _kCard,
                        border  : _kDivider,
                        textColor: Colors.white70,
                        loading  : _saving,
                        onTap    : _saving ? null : _save,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Send Now
                    Expanded(
                      child: _ActionButton(
                        label    : _sending ? 'Sending…' : 'Send Report Now',
                        icon     : _sending ? null : Icons.send_rounded,
                        color    : _kOrange,
                        border   : _kOrange,
                        textColor: Colors.white,
                        loading  : _sending,
                        onTap    : _sending ? null : _sendNow,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // ── What's included ──────────────────────────────
                _sectionLabel('WHAT THE EMAIL INCLUDES'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kDivider),
                  ),
                  child: Column(
                    children: [
                      _includeRow(Icons.payments_rounded,            const Color(0xFF4ADE80), 'Total Sales (Today)'),
                      _includeRow(Icons.money_rounded,               const Color(0xFFFBBF24), 'Cash Collection'),
                      _includeRow(Icons.phone_android_rounded,       const Color(0xFF3B82F6), 'UPI / Online Payments'),
                      _includeRow(Icons.inventory_2_rounded,         _kOrange,               'Product-wise Qty & Revenue'),
                      _includeRow(Icons.account_balance_wallet_rounded, Colors.redAccent,    'Today\'s Expenses'),
                      _includeRow(Icons.trending_up_rounded,         const Color(0xFFA855F7), 'Net Profit After Expenses'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    ),
  );

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText     : hint,
        hintStyle    : TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 13),
        prefixIcon   : Icon(icon, color: _kOrange, size: 18),
        filled       : true,
        fillColor    : _kCard,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kDivider, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 1.5)),
      ),
    );
  }

  Widget _darkDropdown({
    required String label,
    required int    value,
    required List<int> items,
    required String Function(int) display,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value    : value,
      dropdownColor: _kCard,
      style    : const TextStyle(color: Colors.white, fontSize: 14),
      icon     : const Icon(Icons.expand_more_rounded, color: Colors.white38),
      decoration: InputDecoration(
        labelText : label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        filled    : true,
        fillColor : _kCard,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kDivider, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 1.5)),
      ),
      items: items.map((i) => DropdownMenuItem(
        value: i,
        child: Text(display(i), style: const TextStyle(color: Colors.white)),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _includeRow(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          const Icon(Icons.check_rounded, color: Color(0xFF4ADE80), size: 15),
        ],
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String   label;
  final IconData? icon;
  final Color    color;
  final Color    border;
  final Color    textColor;
  final bool     loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.border,
    required this.textColor,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? color.withOpacity(0.5) : color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 15, height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            else if (icon != null)
              Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}
