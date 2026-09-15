import 'dart:typed_data';

import 'report_model.dart';

/// Renders a typed [ReportModel] to PDF bytes.
///
/// Nothing else in the app depends on a specific PDF library — only the
/// concrete implementation (in `lib/data/report/`) imports `package:pdf`.
/// This is what lets the report *content* (the model) be built and
/// tested without ever touching PDF rendering.
abstract class ReportRenderer {
  Future<Uint8List> render(ReportModel model);
}
