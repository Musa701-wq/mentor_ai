import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../services/geminiService.dart';
import '../services/creditService.dart';

class MindmapProvider with ChangeNotifier {
  final GeminiService geminiService;
  final _creditsService = CreditsService();

  MindmapProvider({required this.geminiService});

  Graph _graph = Graph()..isTree = true;
  Graph get graph => _graph;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  num _lastCostCredits = 0;
  num get lastCostCredits => _lastCostCredits;

  Map<String, String> _nodeLabels = {};

  String getLabel(String id) {
    return _nodeLabels[id] ?? 'Unknown';
  }

  Future<bool> generateMindmap(String text) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await geminiService.generateMindmap(text);
      if (result['nodes'] == null || result['nodes'].isEmpty) {
        _error = "Could not generate mindmap from the given text.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // ─── Dynamic credit deduction based on token usage ───────────────
      final tokens = geminiService.lastEstimatedTokens;
      _lastCostCredits = CreditsService.calcCreditsFromTokens(tokens);
      await _creditsService.deductCredits(_lastCostCredits);
      debugPrint('💳 Mindmap: deducted $_lastCostCredits credits ($tokens tokens)');

      _graph = Graph()..isTree = true;
      _nodeLabels.clear();

      final nodesData = result['nodes'] as List;
      final edgesData = result['edges'] as List;

      Map<String, Node> nodeMap = {};

      for (var node in nodesData) {
        String id = node['id'].toString();
        String label = node['label'].toString();
        _nodeLabels[id] = label;
        var n = Node.Id(id);
        nodeMap[id] = n;
      }

      for (var edge in edgesData) {
        String from = edge['from'].toString();
        String to = edge['to'].toString();
        if (nodeMap.containsKey(from) && nodeMap.containsKey(to)) {
          _graph.addEdge(nodeMap[from]!, nodeMap[to]!);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Error: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update a node's label (for tap-to-edit)
  void updateLabel(String id, String newLabel) {
    if (newLabel.isNotEmpty) {
      _nodeLabels[id] = newLabel;
      notifyListeners();
    }
  }

  void reset() {
    _graph = Graph()..isTree = true;
    _nodeLabels.clear();
    _error = null;
    _isLoading = false;
    _lastCostCredits = 0;
    notifyListeners();
  }
}
