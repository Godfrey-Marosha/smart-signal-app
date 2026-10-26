// Shared enums. The `wire` value is what gets stored in Firestore and MUST
// match the .NET dashboard (Wire.cs). Change these only together with the web team.
import 'package:flutter/material.dart';

T _fromWire<T>(List<T> values, String? wire, String Function(T) getWire, T fallback) {
  for (final v in values) {
    if (getWire(v) == wire) return v;
  }
  return fallback;
}

/// Version 1 covers water and electricity only.
enum Service {
  water('water', 'Water', Icons.water_drop_outlined),
  electricity('electricity', 'Electricity', Icons.bolt_outlined);

  const Service(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static Service fromWire(String? v) => _fromWire(values, v, (e) => e.wire, water);

  /// Statuses that make sense for this service.
  List<ReportStatus> get statuses => switch (this) {
        Service.water => const [ReportStatus.off, ReportStatus.lowPressure, ReportStatus.dirty, ReportStatus.backOn],
        Service.electricity => const [ReportStatus.off, ReportStatus.backOn],
      };
}

enum ReportStatus {
  off('off', 'Off'),
  lowPressure('low_pressure', 'Low pressure'),
  dirty('dirty', 'Dirty water'),
  backOn('back_on', 'Back on');

  const ReportStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ReportStatus fromWire(String? v) => _fromWire(values, v, (e) => e.wire, off);

  bool get isDisruption => this != backOn;
}

/// Set by the dashboard / backend on incidents.
enum IncidentStatus {
  suspected('suspected'),
  confirmed('confirmed'),
  resolved('resolved');

  const IncidentStatus(this.wire);
  final String wire;
  static IncidentStatus fromWire(String? v) => _fromWire(values, v, (e) => e.wire, suspected);
}

enum PredictionType {
  waterOutage('water_outage'),
  powerOutage('power_outage'),
  elecRunout('elec_runout'),
  budgetOverspend('budget_overspend');

  const PredictionType(this.wire);
  final String wire;
  static PredictionType fromWire(String? v) => _fromWire(values, v, (e) => e.wire, waterOutage);
}

enum ReadingKind {
  elecUnits('elec_units', 'Units left', 'kWh');

  const ReadingKind(this.wire, this.label, this.unit);
  final String wire;
  final String label;
  final String unit;
  static ReadingKind fromWire(String? v) => _fromWire(values, v, (e) => e.wire, elecUnits);
}

enum AlertSource {
  official('official', 'Official'),
  predicted('predicted', 'Predicted'),
  community('community', 'Community');

  const AlertSource(this.wire, this.label);
  final String wire;
  final String label;
  static AlertSource fromWire(String? v) => _fromWire(values, v, (e) => e.wire, community);
}
