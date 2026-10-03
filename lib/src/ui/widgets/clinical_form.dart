import 'package:flutter/material.dart';
import '../../package/clinical_package.dart';

class ClinicalForm extends StatefulWidget {
  const ClinicalForm({super.key, required this.fields, required this.values});
  final List<ClinicalField> fields;
  final Map<String, dynamic> values;
  @override
  State<ClinicalForm> createState() => _ClinicalFormState();
}

class _ClinicalFormState extends State<ClinicalForm> {
  final Map<Object, Key> _itemKeys = Map.identity();
  // Field labels follow the device language; dictation language is chosen separately.
  String get _language =>
      View.of(context).platformDispatcher.locale.languageCode;
  Widget field(ClinicalField f, Map<String, dynamic> values, String path) {
    final value = values[f.id];
    if (f.type == 'group') {
      final group = values[f.id] as Map<String, dynamic>;
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(f.labelIn(_language),
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final child in f.children)
                      field(child, group, '$path.${child.id}'),
                  ])));
    }
    if (f.type == 'list') {
      final items = values[f.id] as List;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(f.labelIn(_language),
                  style: Theme.of(context).textTheme.titleMedium)),
          TextButton.icon(
              onPressed: () => setState(() => items.add({
                    for (final child in f.children)
                      child.id: child.normalize(null)
                  })),
              icon: const Icon(Icons.add),
              label: const Text('Add'))
        ]),
        for (var i = 0; i < items.length; i++)
          Card(
              key: _itemKeys.putIfAbsent(items[i], UniqueKey.new),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text('${f.labelIn(_language)} ${i + 1}')),
                      IconButton(
                          onPressed: () => setState(() => items.removeAt(i)),
                          icon: const Icon(Icons.delete_outline))
                    ]),
                    for (final child in f.children)
                      field(child, items[i] as Map<String, dynamic>,
                          '$path.$i.${child.id}'),
                  ]))),
      ]);
    }
    final label = '${f.labelIn(_language)}${f.requiredValue ? ' *' : ''}';
    if (f.type == 'boolean' || f.type == 'choice') {
      final options = f.type == 'boolean' ? <dynamic>[true, false] : f.options;
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonFormField<dynamic>(
            initialValue: value,
            decoration: InputDecoration(labelText: label),
            items: [
              const DropdownMenuItem(value: null, child: Text('Not specified')),
              for (final option in options)
                DropdownMenuItem(value: option, child: Text('$option'))
            ],
            onChanged: (v) => setState(() => values[f.id] = v),
            validator: (v) => f.requiredValue && v == null ? 'Required' : null,
          ));
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          keyboardType: f.type == 'number'
              ? const TextInputType.numberWithOptions(
                  decimal: true, signed: true)
              : TextInputType.text,
          onChanged: (v) => values[f.id] = v.isEmpty
              ? null
              : f.type == 'number'
                  ? num.tryParse(v)
                  : v,
          validator: (v) {
            if (f.requiredValue && (v == null || v.trim().isEmpty)) {
              return 'Required';
            }
            if (f.type == 'number' &&
                v != null &&
                v.isNotEmpty &&
                (num.tryParse(v) == null || !num.parse(v).isFinite)) {
              return 'Enter a finite number';
            }
            return null;
          },
        ));
  }

  @override
  Widget build(BuildContext context) => Column(
      children: [for (final f in widget.fields) field(f, widget.values, f.id)]);
}
