import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

void main() {
  // Datos de fechas en español (se usan en "Reporte del día").
  initializeDateFormatting();
  runApp(const SensaApp());
}
