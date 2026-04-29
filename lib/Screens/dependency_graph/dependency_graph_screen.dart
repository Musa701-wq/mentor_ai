import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphview/GraphView.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../Providers/dependencyGraphProvider.dart';

class DependencyGraphScreen extends StatefulWidget {
  const DependencyGraphScreen({Key? key}) : super(key: key);

  @override
  _DependencyGraphScreenState createState() => _DependencyGraphScreenState();
}

class _DependencyGraphScreenState extends State<DependencyGraphScreen> {
  final TextEditingController _textController = TextEditingController();
  final SugiyamaConfiguration builder = SugiyamaConfiguration();
  bool _isSaving = false;

  // Gradient palettes matching a blue theme
  static const List<List<Color>> _nodeGradients = [
    [Color(0xFF2196F3), Color(0xFF03A9F4)],
    [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
    [Color(0xFFFF9800), Color(0xFFFF5722)],
    [Color(0xFF9C27B0), Color(0xFF673AB7)],
  ];

  @override
  void initState() {
    super.initState();
    builder
      ..nodeSeparation = 30
      ..levelSeparation = 65 // Increased space between layers
      ..orientation = 1; // 1 = Top to Bottom
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _snack('Please enter a topic first.', isError: true);
      return;
    }
    final provider = Provider.of<DependencyGraphProvider>(context, listen: false);
    final success = await provider.generateDependencyGraph(text);

    if (!success && mounted && provider.error != null) {
      _snack(provider.error!, isError: true);
    } else if (success && mounted) {
      _snack('🎯 Dependency Graph generated! ${provider.lastCostCredits} credits used.', color: const Color(0xFF2196F3));
    }
  }

  void _snack(String msg, {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : (color ?? const Color(0xFF2196F3)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _savePdf() async {
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<DependencyGraphProvider>(context, listen: false);
      final graph = provider.graph;

      if (graph.nodes.isEmpty) {
        _snack('Dependency Graph is empty.', isError: true);
        return;
      }

      // 1. Build Relationships
      final Map<String, List<String>> children = {};
      String? rootId;
      final Set<String> hasParent = {};

      for (final edge in graph.edges) {
        final from = edge.source.key!.value.toString();
        final to = edge.destination.key!.value.toString();
        children.putIfAbsent(from, () => []).add(to);
        hasParent.add(to);
      }

      for (final node in graph.nodes) {
        final id = node.key!.value.toString();
        if (!hasParent.contains(id)) {
          rootId = id;
          break;
        }
      }
      rootId ??= graph.nodes.first.key!.value.toString();

      // 2. Unit Space Layout
      const double uNodeW = 160.0;
      const double uNodeH = 50.0;
      const double uHGap = 20.0;
      const double uVGap = 80.0;

      final Map<String, double> subtreeWidth = {};
      double calcWidth(String id) {
        final kids = children[id] ?? [];
        if (kids.isEmpty) return subtreeWidth[id] = uNodeW;
        double total = kids.fold(0.0, (acc, k) => acc + calcWidth(k)) + (kids.length - 1) * uHGap;
        return subtreeWidth[id] = total;
      }
      calcWidth(rootId);

      final Map<String, Offset> uPositions = {};
      void assignUPositions(String id, double cx, double y) {
        uPositions[id] = Offset(cx, y);
        final kids = children[id] ?? [];
        if (kids.isEmpty) return;
        double totalKidsW = kids.fold(0.0, (acc, k) => acc + subtreeWidth[k]!) + (kids.length - 1) * uHGap;
        double left = cx - totalKidsW / 2;
        for (final kid in kids) {
          assignUPositions(kid, left + subtreeWidth[kid]! / 2, y + uNodeH + uVGap);
          left += subtreeWidth[kid]! + uHGap;
        }
      }
      assignUPositions(rootId, 0, 0);

      if (uPositions.isEmpty) return;

      // 3. Normalization (Unit space bounds)
      double minX = uPositions.values.map((p) => p.dx - uNodeW / 2).reduce((a, b) => a < b ? a : b);
      double maxX = uPositions.values.map((p) => p.dx + uNodeW / 2).reduce((a, b) => a > b ? a : b);
      double maxY = uPositions.values.map((p) => p.dy + uNodeH).reduce((a, b) => a > b ? a : b);
      double natW = maxX - minX;

      // 4. Scaling Calculation
      const double targetW = 800.0;
      const double padding = 50.0;
      const double headerH = 70.0;
      final double drawableW = targetW - (padding * 2);
      final double scale = (natW > drawableW) ? (drawableW / natW) : 1.0;

      final double pdfW = targetW;
      final double pdfH = (maxY * scale) + (padding * 2) + headerH;

      // 5. PDF Setup
      final PdfDocument doc = PdfDocument();
      doc.pageSettings.size = Size(pdfW, pdfH);
      doc.pageSettings.margins.all = 0;
      final PdfPage page = doc.pages.add();
      final PdfGraphics g = page.graphics;

      // Helper for manual transformation
      double tx(double ux) => padding + (drawableW - natW * scale) / 2 + (ux - minX) * scale;
      double ty(double uy) => headerH + padding + uy * scale;
      final double sNodeW = uNodeW * scale;
      final double sNodeH = uNodeH * scale;

      // Backgrounds
      g.drawRectangle(brush: PdfSolidBrush(PdfColor(248, 249, 253)), bounds: Rect.fromLTWH(0, 0, pdfW, pdfH));
      g.drawRectangle(brush: PdfSolidBrush(PdfColor(33, 150, 243)), bounds: Rect.fromLTWH(0, 0, pdfW, headerH));
      g.drawString(
        'Dependency Graph',
        PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(padding, 23, pdfW, 40),
      );

      final List<PdfColor> nodeColors = [
        PdfColor(33, 150, 243), PdfColor(108, 99, 255), PdfColor(255, 152, 0), PdfColor(156, 39, 176),
      ];

      // Draw Edges
      for (final edge in graph.edges) {
        final f = uPositions[edge.source.key!.value.toString()]!;
        final t = uPositions[edge.destination.key!.value.toString()]!;
        final double fx = tx(f.dx);
        final double fy = ty(f.dy) + sNodeH;
        final double txPos = tx(t.dx);
        final double tyPos = ty(t.dy);
        final double midY = (fy + tyPos) / 2;

        final path = PdfPath();
        path.addBezier(Offset(fx, fy), Offset(fx, midY), Offset(txPos, midY), Offset(txPos, tyPos));
        g.drawPath(path, pen: PdfPen(PdfColor(180, 180, 210), width: 1.5 * scale));
      }

      // Draw Nodes
      final double fontSize = (12 * scale).clamp(8.0, 14.0);
      final PdfFont labelFont = PdfStandardFont(PdfFontFamily.helvetica, fontSize, style: PdfFontStyle.bold);
      final PdfStringFormat fmt = PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle);

      uPositions.forEach((id, pos) {
        final label = provider.getLabel(id);
        final color = nodeColors[(int.tryParse(id) ?? id.hashCode).abs() % nodeColors.length];
        final double nx = tx(pos.dx) - sNodeW / 2;
        final double ny = ty(pos.dy);
        final Rect r = Rect.fromLTWH(nx, ny, sNodeW, sNodeH);

        g.drawRectangle(brush: PdfSolidBrush(PdfColor(0, 0, 0, 15)), bounds: r.shift(Offset(2 * scale, 3 * scale)));
        g.drawRectangle(brush: PdfSolidBrush(color), bounds: r);
        g.drawString(label, labelFont, brush: PdfSolidBrush(PdfColor(255, 255, 255)), bounds: r.inflate(-4 * scale), format: fmt);
      });

      // 6. Save
      final bytes = await doc.save();
      doc.dispose();

      Directory saveDir;
      try {
        if (Platform.isAndroid) {
          final dl = Directory('/storage/emulated/0/Download');
          saveDir = (await dl.exists()) ? dl : (await getExternalStorageDirectory())!;
        } else {
          saveDir = await getApplicationDocumentsDirectory();
        }
      } catch (_) {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'Dependency_Graph_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final where = Platform.isAndroid ? 'Downloads' : 'Files app';
      _snack('✅ Saved to $where', color: const Color(0xFF4CAF50));
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildNode(String id, String label) {
    final idx = (int.tryParse(id) ?? id.hashCode).abs() % _nodeGradients.length;
    final colors = _nodeGradients[idx];

    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.35), offset: const Offset(0, 4), blurRadius: 10)],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildInputView(DependencyGraphProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 30, offset: const Offset(0, 15))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.account_tree_rounded, color: Color(0xFF2196F3)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Enter Topic', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('e.g., Machine Learning, Flutter', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your topic here...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(18),
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (provider.isLoading) ...[
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 52, height: 52,
                    child: CircularProgressIndicator(strokeWidth: 5, valueColor: AlwaysStoppedAnimation(Color(0xFF2196F3))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Building learning path...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('AI is organizing topic dependencies', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.15)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2196F3), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This graph will show you the exact chronological order of what to learn first.',
                      style: TextStyle(color: Color(0xFF2196F3), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _handleGenerate,
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              label: const Text('Generate Topic Graph', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
                shadowColor: const Color(0xFF2196F3).withOpacity(0.4),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildGraphView(DependencyGraphProvider provider) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('Pinch to zoom  •  Top to bottom flow', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: 0.2,
                maxScale: 3.5,
                panEnabled: true,
                scaleEnabled: true,
                child: GraphView(
                  graph: provider.graph,
                  algorithm: SugiyamaAlgorithm(builder),
                  paint: Paint()
                    ..color = const Color(0xFF2196F3).withOpacity(0.8)
                    ..strokeWidth = 2.0
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final id = node.key!.value.toString();
                    final label = provider.getLabel(id);
                    return _buildNode(id, label);
                  },
                ),
              ),
            ),
          ),
        SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => provider.reset(),
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2196F3)),
                    label: const Text('New Graph', style: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: _isSaving ? null : _savePdf,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save as PDF',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DependencyGraphProvider>(
      builder: (context, provider, _) {
        final bool hasGraph = provider.graph.nodes.isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            physics: hasGraph ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: hasGraph ? 100 : 180,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    hasGraph ? 'Dependency Flow' : 'Topic Dependency',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF90CAF9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Opacity(
                      opacity: 0.1,
                      child: Icon(Icons.account_tree_rounded, size: 200, color: Colors.white),
                    ),
                  ),
                ),
                actions: hasGraph ? [
                  IconButton(
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Save as PDF',
                    onPressed: _isSaving ? null : _savePdf,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: 'Create another',
                    onPressed: () => provider.reset(),
                  ),
                ] : null,
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: hasGraph
                    ? _buildGraphView(provider)
                    : _buildInputView(provider),
              ),
            ],
          ),
        );
      },
    );
  }
}
