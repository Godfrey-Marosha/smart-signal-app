import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/records.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.primary),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleSmall, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class ServiceAvatar extends StatelessWidget {
  const ServiceAvatar(this.service, {super.key, this.alert = false});
  final Service service;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = alert ? Brand.amber : scheme.primary;
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: alert ? const Color(0xFF8A5A00) : scheme.primary,
      child: Icon(service.icon),
    );
  }
}

/// A forecast card on the Home screen: what, how likely, and one action.
class ForecastCard extends StatelessWidget {
  const ForecastCard(this.p, {super.key, this.done = false, this.onDone});
  final Prediction p;

  /// True once the resident tapped "Done" on the action.
  final bool done;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final urgent = p.type == PredictionType.waterOutage || p.type == PredictionType.powerOutage || p.type == PredictionType.elecRunout;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceAvatar(p.service ?? Service.electricity, alert: urgent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(p.detail, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (p.probability != null) ...[
                  const SizedBox(width: 8),
                  _ProbabilityBadge(p.probability!),
                ],
              ],
            ),
            if (p.action.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(done ? Icons.check_circle : Icons.check_circle_outline, size: 18, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.action,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (onDone != null)
                      done
                          ? Text('Done', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700))
                          : TextButton(
                              onPressed: onDone,
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('Done'),
                            ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProbabilityBadge extends StatelessWidget {
  const _ProbabilityBadge(this.p);
  final double p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Brand.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(percent(p), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A5A00))),
    );
  }
}

/// A small label + value tile for Insights.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption});
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (caption != null) Text(caption!, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
