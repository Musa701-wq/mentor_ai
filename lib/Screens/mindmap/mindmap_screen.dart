import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:graphview/GraphView.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../Providers/mindmapProvider.dart';
import '../../services/ocrService.dart';

class MindmapScreen extends StatefulWidget {
  @override
  _MindmapScreenState createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> {
  final TextEditingController _textController = TextEditingController();
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();
  bool _isExtracting = false;
  bool _isSaving = false;

  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  // Gradient palettes matching home screen cards
  static const List<List<Color>> _nodeGradients = [
    [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
    [Color(0xFF2196F3), Color(0xFF03A9F4)],
    [Color(0xFFFF9800), Color(0xFFFF5722)],
    [Color(0xFF9C27B0), Color(0xFF673AB7)],
    [Color(0xFFE91E63), Color(0xFFC2185B)],
    [Color(0xFF00BCD4), Color(0xFF0097A7)],
    [Color(0xFF4CAF50), Color(0xFF2E7D32)],
    [Color(0xFFFF5252), Color(0xFFD32F2F)],
  ];

  @override
  void initState() {
    super.initState();
    builder
      ..siblingSeparation = 55
      ..levelSeparation = 65
      ..subtreeSeparation = 55
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  @override
  void dispose() {
    _textController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ─── OCR Image Pick ────────────────────────────────────────────────────────
  Future<void> _pickImageAndExtract() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    setState(() => _isExtracting = true);
    try {
      final text = await _ocrService.extractTextFromImage(File(picked.path));
      if (text.trim().isEmpty) {
        _snack('No text found in the image. Try a clearer photo.', isError: true);
      } else {
        _textController.text = text.trim();
        _snack('✅ Text extracted! Review and tap Generate.', color: const Color(0xFF6C63FF));
      }
    } catch (e) {
      _snack('Failed to extract text: $e', isError: true);
    } finally {
      setState(() => _isExtracting = false);
    }
  }

  // ─── Generate ──────────────────────────────────────────────────────────────
  Future<void> _handleGenerate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _snack('Please enter text or upload an image first.', isError: true);
      return;
    }
    final provider = Provider.of<MindmapProvider>(context, listen: false);
    final success = await provider.generateMindmap(text);

    if (!success && mounted && provider.error != null) {
      _snack(provider.error!, isError: true);
    } else if (success && mounted) {
      _snack('🧠 Mindmap generated! ${provider.lastCostCredits} credits used.', color: const Color(0xFF4CAF50));
    }
  }

  // ─── Edit node label ────────────────────────────────────────────────────────
  void _editNode(BuildContext context, String id, String currentLabel) {
    final ctrl = TextEditingController(text: currentLabel);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.edit_rounded, color: const Color(0xFF6C63FF), size: 22),
          SizedBox(width: 10),
          Text('Edit Node', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Node label...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Provider.of<MindmapProvider>(context, listen: false).updateLabel(id, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Save as PDF (Manual Scale-to-Fit, Full Tree) ─────────────────────────
  Future<void> _savePdf() async {
    setState(() => _isSaving = true);
    try {
      final provider = Provider.of<MindmapProvider>(context, listen: false);
      final graph = provider.graph;

      if (graph.nodes.isEmpty) {
        _snack('Mindmap is empty.', isError: true);
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
      g.drawRectangle(brush: PdfSolidBrush(PdfColor(45, 27, 105)), bounds: Rect.fromLTWH(0, 0, pdfW, headerH));
      g.drawString(
        'AI Mindmap Result',
        PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(padding, 23, pdfW, 40),
      );

      final List<PdfColor> nodeColors = [
        PdfColor(108, 99, 255), PdfColor(33, 150, 243), PdfColor(255, 152, 0), PdfColor(156, 39, 176),
        PdfColor(233, 30, 99), PdfColor(0, 188, 212), PdfColor(76, 175,  80), PdfColor(255,  82, 82),
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

      final fileName = 'AI_Mindmap_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

  // ─── Node widget ────────────────────────────────────────────────────────────
  Widget _buildNode(String id, String label, BuildContext ctx) {
    final idx = (int.tryParse(id) ?? id.hashCode).abs() % _nodeGradients.length;
    final colors = _nodeGradients[idx];

    return GestureDetector(
      onTap: () => _editNode(ctx, id, label),
      child: Container(
        constraints: BoxConstraints(maxWidth: 155),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: colors[0].withOpacity(0.35), offset: Offset(0, 4), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label, textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            SizedBox(width: 6),
            Icon(Icons.edit, color: Colors.white.withOpacity(0.6), size: 12),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : (color ?? const Color(0xFF6C63FF)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(seconds: 3),
    ));
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<MindmapProvider>(
      builder: (context, provider, _) {
        final bool hasGraph = provider.graph.nodes.isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            physics: hasGraph ? NeverScrollableScrollPhysics() : BouncingScrollPhysics(),
            slivers: [
              // ─── Premium SliverAppBar ─────────────────────────────────────
              SliverAppBar(
                expandedHeight: hasGraph ? 100 : 180,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    hasGraph ? 'Your Mindmap' : 'AI Mindmap',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2D1B69), Color(0xFF6C63FF), Color(0xFF9C8FFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(Icons.account_tree_rounded, size: 200, color: Colors.white),
                    ),
                  ),
                ),
                actions: hasGraph ? [
                  IconButton(
                    icon: _isSaving
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Save as PDF',
                    onPressed: _isSaving ? null : _savePdf,
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: 'Create another',
                    onPressed: () => provider.reset(),
                  ),
                ] : [
                  IconButton(
                    icon: Icon(Icons.help_outline_rounded, color: Colors.white),
                    onPressed: () => _showHowItWorks(),
                  )
                ],
              ),

              // ─── Body ────────────────────────────────────────────────────
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

  // ─── Input Screen ──────────────────────────────────────────────────────────
  Widget _buildInputView(MindmapProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main input card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 30, offset: Offset(0, 15))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.account_tree_rounded, color: const Color(0xFF6C63FF)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Content', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('Type, paste, or upload an image', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Text area
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _textController,
                          maxLines: 7,
                          decoration: InputDecoration(
                            hintText: 'Paste your notes, chapter content, or topic here...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(18),
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                          ),
                          style: TextStyle(fontSize: 15, height: 1.5),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            children: [
                              _buildSmallIconBtn(
                                icon: _isExtracting ? null : Icons.image_outlined,
                                isLoading: _isExtracting,
                                color: Colors.blue,
                                onTap: _isExtracting ? null : _pickImageAndExtract,
                                label: 'Upload Image',
                              ),
                              Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Loading state inside the input view
          if (provider.isLoading) _buildLoadingCard(),

          if (!provider.isLoading) ...[
            // Tips card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: const Color(0xFF6C63FF), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Paste a full chapter or topic for a richer mindmap. You can edit nodes after generation.',
                      style: TextStyle(color: const Color(0xFF6C63FF), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Generate button
            ElevatedButton.icon(
              onPressed: _handleGenerate,
              icon: Icon(Icons.auto_awesome_rounded, color: Colors.white),
              label: Text('Generate Mindmap', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
                shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Graph Result Screen ───────────────────────────────────────────────────
  Widget _buildGraphView(MindmapProvider provider) {
    return Column(
      children: [
        // Hint bar
        Container(
          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: Colors.grey[500]),
              SizedBox(width: 6),
              Text('Tap any node to edit  •  Pinch to zoom', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Graph area
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: InteractiveViewer(
                constrained: false,
                boundaryMargin: EdgeInsets.all(400),
                minScale: 0.2,
                maxScale: 3.5,
                panEnabled: true,
                scaleEnabled: true,
                child: GraphView(
                  graph: provider.graph,
                  algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
                  paint: Paint()
                    ..color = Colors.grey.withOpacity(0.45)
                    ..strokeWidth = 1.8
                    ..style = PaintingStyle.stroke,
                  builder: (Node node) {
                    final id = node.key!.value.toString();
                    final label = provider.getLabel(id);
                    return _buildNode(id, label, context);
                  },
                ),
              ),
            ),
          ),

        // Bottom action bar
        SafeArea(
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: const Color(0xFF6C63FF), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => provider.reset(),
                    icon: Icon(Icons.refresh_rounded, color: const Color(0xFF6C63FF)),
                    label: Text('New', style: TextStyle(color: const Color(0xFF6C63FF), fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: _isSaving ? null : _savePdf,
                    icon: _isSaving
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.download_rounded, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save as PDF',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 52, height: 52,
            child: CircularProgressIndicator(strokeWidth: 5, valueColor: AlwaysStoppedAnimation(const Color(0xFF6C63FF))),
          ),
          SizedBox(height: 20),
          Text('Building your mindmap...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('AI is analysing and structuring your content', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildSmallIconBtn({required IconData? icon, required Color color, required VoidCallback? onTap, required String label, bool isLoading = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
            else
              Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showHowItWorks() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('How it Works', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
            ]),
            SizedBox(height: 20),
            _step(Icons.edit_note_rounded, 'Type your topic or paste chapter notes.'),
            _step(Icons.image_outlined, 'Or upload an image — we extract text via OCR.'),
            _step(Icons.account_tree_rounded, 'AI generates a structured visual mindmap.'),
            _step(Icons.edit_rounded, 'Tap any node to edit its label.'),
            _step(Icons.download_rounded, 'Save the mindmap as a PNG image to share.'),
          ],
        ),
      ),
    );
  }

  Widget _step(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, height: 1.4))),
        ],
      ),
    );
  }
}
