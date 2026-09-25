import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/design_system.dart';

/// The pen colours offered for marking up a defect photo (QA #14) —
/// high-contrast on both light walls and dark fittings.
const annotationColors = <({String name, Color color})>[
  (name: 'Red', color: Color(0xFFE53935)),
  (name: 'Yellow', color: Color(0xFFFFD600)),
  (name: 'Blue', color: Color(0xFF1E88E5)),
  (name: 'White', color: Color(0xFFFFFFFF)),
];

/// One freehand stroke, in the photo's own pixel coordinates, so it
/// lands in the same place however the photo is displayed or exported.
class AnnotationStroke {
  AnnotationStroke({required this.color, required List<Offset> points})
    : points = List.unmodifiable(points);

  final Color color;
  final List<Offset> points;
}

/// The drawing state behind the annotation screen: strokes plus the
/// selected colour, with undo and clear. Pure logic, no widgets.
class AnnotationDrawing extends ChangeNotifier {
  final List<AnnotationStroke> _strokes = [];
  List<Offset>? _current;
  Color color = annotationColors.first.color;

  List<AnnotationStroke> get strokes => [
    ..._strokes,
    if (_current != null && _current!.isNotEmpty)
      AnnotationStroke(color: color, points: _current!),
  ];

  bool get isEmpty => _strokes.isEmpty && (_current?.isEmpty ?? true);
  bool get canUndo => _strokes.isNotEmpty;

  void selectColor(Color value) {
    color = value;
    notifyListeners();
  }

  void startStroke(Offset imagePoint) {
    _current = [imagePoint];
    notifyListeners();
  }

  void extendStroke(Offset imagePoint) {
    final current = _current;
    if (current == null) return;
    current.add(imagePoint);
    notifyListeners();
  }

  void endStroke() {
    final current = _current;
    _current = null;
    if (current != null && current.isNotEmpty) {
      _strokes.add(AnnotationStroke(color: color, points: current));
    }
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _current = null;
    notifyListeners();
  }
}

/// Pen width relative to the photo, so markup reads the same on a small
/// or a large photo.
double _strokeWidthFor(Size imageSize) =>
    math.max(3, imageSize.longestSide * 0.006);

void _paintStrokes(
  Canvas canvas,
  List<AnnotationStroke> strokes, {
  required double scale,
  required double strokeWidth,
}) {
  for (final stroke in strokes) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.single * scale,
        strokeWidth * scale / 2,
        paint..style = PaintingStyle.fill,
      );
      continue;
    }
    final path = Path()
      ..moveTo(stroke.points.first.dx * scale, stroke.points.first.dy * scale);
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx * scale, point.dy * scale);
    }
    canvas.drawPath(path, paint);
  }
}

/// The longest edge of an exported annotated copy. The original photo
/// is kept at full quality regardless; this copy is for viewing and the
/// report, and PNG keeps the markup crisp.
const kAnnotatedCopyMaxEdge = 2560;

/// Renders [image] with [strokes] on top as PNG bytes — never cropped,
/// aspect ratio preserved, downscaled only if its long edge exceeds
/// [kAnnotatedCopyMaxEdge].
Future<Uint8List> renderAnnotatedPng(
  ui.Image image,
  List<AnnotationStroke> strokes,
) async {
  final source = Size(image.width.toDouble(), image.height.toDouble());
  final scale = source.longestSide > kAnnotatedCopyMaxEdge
      ? kAnnotatedCopyMaxEdge / source.longestSide
      : 1.0;
  final width = (source.width * scale).round();
  final height = (source.height * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Offset.zero & source,
    Offset.zero & Size(width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  _paintStrokes(
    canvas,
    strokes,
    scale: scale,
    strokeWidth: _strokeWidthFor(source),
  );
  final rendered = await recorder.endRecording().toImage(width, height);
  final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  rendered.dispose();
  return bytes!.buffer.asUint8List();
}

Future<ui.Image> _loadImage(String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Opens the annotation screen for the photo at [filePath] (always the
/// original — markup is never drawn over an earlier markup) and returns
/// the annotated PNG bytes, or null if the inspector cancels.
Future<Uint8List?> showPhotoAnnotation(
  BuildContext context, {
  required String filePath,
}) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoAnnotationScreen(filePath: filePath),
    ),
  );
}

/// Freehand markup over a defect photo (QA #14): pick a colour, draw,
/// undo, clear, save. The photo is shown whole (never cropped), in its
/// own orientation. Saving pops the annotated PNG bytes; the original
/// file is only ever read.
class PhotoAnnotationScreen extends StatefulWidget {
  const PhotoAnnotationScreen({
    required this.filePath,
    this.imageLoader,
    super.key,
  });

  final String filePath;

  /// Test seam: loads the photo instead of reading [filePath].
  @visibleForTesting
  final Future<ui.Image> Function()? imageLoader;

  @override
  State<PhotoAnnotationScreen> createState() => _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends State<PhotoAnnotationScreen> {
  final _drawing = AnnotationDrawing();
  ui.Image? _image;
  Object? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    (widget.imageLoader ?? () => _loadImage(widget.filePath))().then(
      (image) {
        if (mounted) {
          setState(() => _image = image);
        } else {
          image.dispose();
        }
      },
      onError: (Object error) {
        if (mounted) setState(() => _loadError = error);
      },
    );
  }

  @override
  void dispose() {
    _drawing.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null) return;
    setState(() => _saving = true);
    final bytes = await renderAnnotatedPng(image, _drawing.strokes);
    if (!mounted) return;
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Mark Up Photo'),
        actions: [
          // Rebuilt as strokes change, so Save enables once there is
          // markup to save.
          ListenableBuilder(
            listenable: _drawing,
            builder: (context, _) => TextButton(
              onPressed: image == null || _saving || _drawing.isEmpty
                  ? null
                  : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: image == null
                  ? Center(
                      child: _loadError == null
                          ? const CircularProgressIndicator()
                          : const Text(
                              'This photo could not be opened.',
                              style: TextStyle(color: Colors.white),
                            ),
                    )
                  : _DrawingCanvas(image: image, drawing: _drawing),
            ),
            ListenableBuilder(
              listenable: _drawing,
              builder: (context, _) => _Toolbar(drawing: _drawing),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingCanvas extends StatelessWidget {
  const _DrawingCanvas({required this.image, required this.drawing});

  final ui.Image image;
  final AnnotationDrawing drawing;

  @override
  Widget build(BuildContext context) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        // Whole photo, aspect ratio preserved (portrait or landscape).
        final fitted = applyBoxFit(BoxFit.contain, imageSize, box);
        final rect = Alignment.center.inscribe(
          fitted.destination,
          Offset.zero & box,
        );
        final scale = rect.width / imageSize.width;
        Offset toImage(Offset local) {
          final point = (local - rect.topLeft) / scale;
          return Offset(
            point.dx.clamp(0, imageSize.width),
            point.dy.clamp(0, imageSize.height),
          );
        }

        return GestureDetector(
          key: const ValueKey('annotation-canvas'),
          onPanStart: (d) => drawing.startStroke(toImage(d.localPosition)),
          onPanUpdate: (d) => drawing.extendStroke(toImage(d.localPosition)),
          onPanEnd: (_) => drawing.endStroke(),
          child: ListenableBuilder(
            listenable: drawing,
            builder: (context, _) => CustomPaint(
              size: box,
              painter: _AnnotationPainter(
                image: image,
                rect: rect,
                scale: scale,
                strokes: drawing.strokes,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.image,
    required this.rect,
    required this.scale,
    required this.strokes,
  });

  final ui.Image image;
  final Rect rect;
  final double scale;
  final List<AnnotationStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, Offset.zero & imageSize, rect, Paint());
    canvas.save();
    canvas.translate(rect.left, rect.top);
    _paintStrokes(
      canvas,
      strokes,
      scale: scale,
      strokeWidth: _strokeWidthFor(imageSize),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.drawing});

  final AnnotationDrawing drawing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final option in annotationColors)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Semantics(
                button: true,
                selected: drawing.color == option.color,
                label: '${option.name} pen',
                child: InkWell(
                  key: ValueKey('pen-${option.name}'),
                  customBorder: const CircleBorder(),
                  onTap: () => drawing.selectColor(option.color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: drawing.color == option.color
                            ? Colors.white
                            : Colors.white24,
                        width: drawing.color == option.color ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Undo',
            color: Colors.white,
            disabledColor: Colors.white24,
            onPressed: drawing.canUndo ? drawing.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Clear',
            color: Colors.white,
            disabledColor: Colors.white24,
            onPressed: drawing.isEmpty ? null : drawing.clear,
            icon: const Icon(Icons.layers_clear_outlined),
          ),
        ],
      ),
    );
  }
}
