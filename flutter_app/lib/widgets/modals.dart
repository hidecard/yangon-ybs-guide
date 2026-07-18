import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import 'route_badge.dart';

/// Feedback dialog (bug / wrong info / suggestion / other).
class FeedbackDialog extends StatefulWidget {
  final String? defaultRouteId;
  const FeedbackDialog({super.key, this.defaultRouteId});

  static Future<void> show(BuildContext context, {String? routeId}) {
    return showDialog(
      context: context,
      builder: (_) => FeedbackDialog(defaultRouteId: routeId),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  FeedbackType _type = FeedbackType.suggestion;
  final _msg = TextEditingController();
  late final TextEditingController _route =
      TextEditingController(text: widget.defaultRouteId ?? '');
  bool _submitting = false;
  String? _error;
  bool _success = false;

  Future<void> _submit() async {
    if (_msg.text.trim().isEmpty) {
      setState(() => _error = 'မှတ်ချက် ထည့်ပါ။');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final userId = await LocalStore.instance.getUserId();
    final ok = await ApiService.instance.postFeedback(
      type: _type,
      message: _msg.text.trim(),
      routeId: _route.text.trim(),
      userId: userId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _success = true);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() => _error = 'အမှားရှိပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.chat_bubble_outline, color: AppColors.brand),
                  SizedBox(width: 8),
                  Text('အကြံပြုချက် / အမှားတွက်',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('အမျိုးအစား', style: uiLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FeedbackType.values.map((t) {
                  final active = _type == t;
                  return ChoiceChip(
                    label: Text(feedbackTypeLabels[t]!),
                    selected: active,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.brandLight,
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _route,
                decoration: const InputDecoration(
                    labelText: 'ကားလိုင်းနံပါတ် (ရှိလျှင်)',
                    hintText: 'ဥပမာ - ၁၂၃'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msg,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'မှတ်ချက်', hintText: 'အသေးစိတ် အချက်အလက်...'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: AppColors.rose, fontSize: 12)),
              ],
              if (_success) ...[
                const SizedBox(height: 8),
                const Text('✅ ကျေးဇူးတင်ပါသည်။ လက်ခံပြီးပါပြီ။',
                    style: TextStyle(color: AppColors.emerald, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _submitting || _success ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: const Text('မျှဝေမည်'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Report a community bus update (started / reached / road closed / etc.)
class ReportUpdateDialog extends StatefulWidget {
  final String routeId;
  final String routeLabel;
  const ReportUpdateDialog(
      {super.key, required this.routeId, required this.routeLabel});

  static Future<bool?> show(BuildContext context,
      {required String routeId, required String routeLabel}) {
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          ReportUpdateDialog(routeId: routeId, routeLabel: routeLabel),
    );
  }

  @override
  State<ReportUpdateDialog> createState() => _ReportUpdateDialogState();
}

class _ReportUpdateDialogState extends State<ReportUpdateDialog> {
  BusUpdateType _type = BusUpdateType.started;
  final _stop = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final userId = await LocalStore.instance.getUserId();
    final ok = await ApiService.instance.postBusUpdate(BusUpdate(
      routeId: widget.routeId,
      type: _type,
      stop: _stop.text.trim().isEmpty ? null : _stop.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      userId: userId,
    ));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'အမှားရှိပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.campaign, color: AppColors.amber),
                    SizedBox(width: 8),
                    Text('အချက်အလက် မျှဝေရန်',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  RouteBadge(
                      routeId: widget.routeId,
                      color: AppColors.emerald,
                      small: true),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(widget.routeLabel,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 16),
                const Text('အချက်အလက် အမျိုးအစား', style: uiLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BusUpdateType.values.map((t) {
                    final meta = updateTypeMeta[t]!;
                    final active = _type == t;
                    return ChoiceChip(
                      avatar: CircleAvatar(
                          radius: 4, backgroundColor: meta.dot),
                      label: Text(meta.label),
                      selected: active,
                      selectedColor: meta.bg,
                      labelStyle: TextStyle(
                          color: active ? meta.color : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                      onSelected: (_) => setState(() => _type = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _stop,
                  decoration: const InputDecoration(
                      labelText: 'မှတ်တိုင် (ရှိလျှင်)',
                      hintText: 'ဥပမာ - ဆူးလေမှတ်တိုင်'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'မှတ်ချက် (ရှိလျှင်)',
                      hintText: 'အသေးစိတ် အချက်အလက်...'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style:
                          const TextStyle(color: AppColors.rose, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.campaign),
                    label: const Text('မျှဝေမည်'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const uiLabel = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppColors.textMuted,
);
