import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../runtime/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> rows =
      ref.read(consultationStoreProvider).rows();
  Future<void> refresh() async {
    await ref.read(outboxProvider).flush();
    if (mounted) {
      setState(() => rows = ref.read(consultationStoreProvider).rows());
    }
  }

  /// Hands validated records over without any server: the user picks the
  /// destination (Files, AirDrop, mail…) in the system share sheet.
  Future<void> export() async {
    try {
      final records = await ref.read(consultationStoreProvider).rows();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/medipop-export-$stamp.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ')
          .convert({'count': records.length, 'records': records}));
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncEnabled = ref.watch(adaptersProvider).sync.enabled;
    return Scaffold(
        appBar: AppBar(title: const Text('History'), actions: [
          IconButton(
              tooltip: 'Export JSON',
              onPressed: export,
              icon: const Icon(Icons.ios_share)),
          if (syncEnabled)
            IconButton(
                tooltip: 'Refresh and sync',
                onPressed: refresh,
                icon: const Icon(Icons.sync)),
        ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: rows,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Cannot read local history.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('No consultations yet.'));
              }
              return ListView(children: [
                for (final record in snapshot.data!)
                  ExpansionTile(
                    title: Text('${record['schema_id']} • ${record['id']}'),
                    subtitle: Text(
                        '${record['created_at']}\n${!syncEnabled ? 'Stored on this device' : record['sent_at'] == null ? 'Saved locally' : 'Synced'}${record['last_error'] == null ? '' : ' • ${record['last_error']}'}'),
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                              'Schema ${record['schema_version']}\n${const JsonEncoder.withIndent('  ').convert(record['payload'])}\n\n${record['raw_transcript']}'))
                    ],
                  )
              ]);
            }));
  }
}
