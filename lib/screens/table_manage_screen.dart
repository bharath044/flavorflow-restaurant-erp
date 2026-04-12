import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';

class TableManageScreen extends StatefulWidget {
  const TableManageScreen({super.key});

  @override
  State<TableManageScreen> createState() => _TableManageScreenState();
}

class _TableManageScreenState extends State<TableManageScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  Future<void> _fetchTables() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await ApiService.getTables();
    if (!mounted) return;
    setState(() {
      _tables = data;
      _isLoading = false;
    });
  }

  void _showAddTableDialog() {
    final noController = TextEditingController();
    final labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Add New Table', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Table ID (e.g. T12)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: labelController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Display Label (e.g. Table 12)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white24)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6A00)),
            onPressed: () async {
              if (noController.text.isNotEmpty) {
                final success = await ApiService.addTable(
                  noController.text.trim(),
                  labelController.text.isEmpty ? noController.text.trim() : labelController.text.trim(),
                );
                if (success) {
                  Navigator.pop(ctx);
                  _fetchTables();
                }
              }
            },
            child: const Text('ADD TABLE'),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(String tableNo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
    );

    final data = await ApiService.getQrForTable(tableNo);
    Navigator.pop(context); // Close loader

    if (!mounted) return;

    if (data.containsKey('qr')) {
      final String base64Image = data['qr'].split(',').last;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text('Table $tableNo QR Code', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.memory(base64Decode(base64Image), width: 250, height: 250),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan this to open Web Menu for $tableNo',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white24)),
            ),
          ],
        ),
      );
    }
  }

  void _deleteTable(String tableNo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to remove Table $tableNo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTable(tableNo);
      if (success) _fetchTables();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00)))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Table Management',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Manage restaurant layout and QR menu codes',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6A00),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAddTableDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('ADD TABLE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _tables.isEmpty
                        ? const Center(child: Text('No tables found', style: TextStyle(color: Colors.white24)))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _tables.length,
                            itemBuilder: (ctx, i) {
                              final t = _tables[i];
                              final no = t['tableNo'];
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.table_restaurant_rounded, color: Color(0xFFFF6A00), size: 42),
                                    const SizedBox(height: 12),
                                    Text(
                                      t['label'] ?? no,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'ID: $no',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white54),
                                          onPressed: () => _showQrDialog(no),
                                          tooltip: 'Show QR',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.6)),
                                          onPressed: () => _deleteTable(no),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
