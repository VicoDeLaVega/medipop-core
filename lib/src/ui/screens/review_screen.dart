import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/consultation.dart';
import '../../runtime/providers.dart';
import '../../services/extraction_service.dart';
import '../widgets/clinical_form.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.draft});
  final ClinicalDraft draft;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final formKey = GlobalKey<FormState>();
  late final values = widget.draft.package.normalize(widget.draft.values);
  bool saving = false;
  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final errors = widget.draft.package.validate(values);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.join('\n'))));
      return;
    }
    setState(() => saving = true);
    try {
      final controller = ref.read(workspaceProvider);
      final workspace = controller.workspace!;
      final store = ref.read(consultationStoreProvider);
      final outbox = ref.read(outboxProvider);
      final device = await controller.deviceId();
      if (!mounted || controller.workspace?.key != workspace.key) return;
      final record = Consultation.create(
          userId: workspace.identity.userId,
          organizationId: workspace.identity.organizationId,
          deviceId: device,
          package: widget.draft.package,
          transcript: widget.draft.transcript,
          payload: values);
      await store.save(record);
      unawaited(outbox.flush());
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Save failed. Your form is still available; retry.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Review ${widget.draft.package.title}')),
      body: Form(
          key: formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.draft.warning != null) Text(widget.draft.warning!),
            ClinicalForm(fields: widget.draft.package.fields, values: values),
            const SizedBox(height: 16),
            const Text('Original dictation'),
            SelectableText(widget.draft.transcript),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Validate & save')),
          ])));
}
