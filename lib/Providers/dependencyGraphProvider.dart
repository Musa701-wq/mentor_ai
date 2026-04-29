import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/geminiService.dart';
import '../services/creditService.dart';
import '../services/Firestore_service.dart';

class DependencyGraphProvider with ChangeNotifier {
  final GeminiService geminiService;
  final _creditsService = CreditsService();
  final FirestoreService _firestoreService = FirestoreService();

  DependencyGraphProvider({required this.geminiService});

  Graph _graph = Graph()..isTree = false;
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

  void loadGraphFromHistory(String topic, Map<String, dynamic> graphData) {
    _graph = Graph()..isTree = false;
    _nodeLabels.clear();

    final nodesData = graphData['nodes'] as List;
    final edgesData = graphData['edges'] as List;

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
    notifyListeners();
  }

  Future<bool> generateDependencyGraph(String topic) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Proactive credit deduction
      final hasEnough = await _creditsService.deductCredits(2.0);
      if (!hasEnough) {
        _error = "Insufficient credits. Generating a dependency graph requires 2.0 credits.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final result = await geminiService.generateDependencyGraph(topic);
      if (result['nodes'] == null || result['nodes'].isEmpty) {
        _error = "Could not generate dependency graph for the given topic.";
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Record tokens for debugging but bypass second deduction
      final tokens = geminiService.lastEstimatedTokens;
      _lastCostCredits = 2.0;
      debugPrint('💳 DependencyGraph: proactively deducted 2.0 credits ($tokens tokens)');

      // Save to Firebase History
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _firestoreService.saveDependencyGraph(
          userId: uid,
          topic: topic,
          rawGraphData: result,
        );
      }

      _graph = Graph()..isTree = false;
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
        // Edge flows from Prerequisite -> Next Topic
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

  void reset() {
    _graph = Graph()..isTree = false;
    _nodeLabels.clear();
    _error = null;
    _isLoading = false;
    _lastCostCredits = 0;
    notifyListeners();
  }
}
