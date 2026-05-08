import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;


class StatsProvider with ChangeNotifier {
  Timer? _timer;

  int _uptime = 0;
  int _totalRequests = 0;
  double _successRate = 100.0;
  int _activeProviders = 0;
  List<dynamic> _trafficData = [];
  List<dynamic> _providers = [];
  bool _isOnline = false;
  
  // New fields for UI enhancement
  List<double> _requestHistory = List.filled(20, 0.0);
  List<Map<String, dynamic>> _activityLog = [];

  StatsProvider() {
    _startPolling();
  }

  int get uptime => _uptime;
  int get totalRequests => _totalRequests;
  double get successRate => _successRate;
  int get activeProviders => _activeProviders;
  List<dynamic> get trafficData => _trafficData;
  List<dynamic> get providers => _providers;
  bool get isOnline => _isOnline;
  List<double> get requestHistory => _requestHistory;
  List<Map<String, dynamic>> get activityLog => _activityLog;

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => fetchStats());
  }

  Future<void> fetchStats() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/stats')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _uptime = data['uptime'] ?? 0;
        
        final newRequests = data['totalRequests'] ?? 0;
        if (newRequests != _totalRequests && _isOnline) {
          _addLog('Request processed by ${data['lastProvider'] ?? 'system'}', 'info');
        }
        
        _totalRequests = newRequests;
        _successRate = double.tryParse(data['successRate'].toString()) ?? 100.0;
        _activeProviders = data['activeProviders'] ?? 0;
        _providers = data['providers'] ?? [];
        _trafficData = data['trafficData']?['countries'] ?? [];
        
        // Update history
        _requestHistory.removeAt(0);
        _requestHistory.add(_totalRequests.toDouble());
        
        _isOnline = true;
      } else {
        if (_isOnline) _addLog('Bridge connection lost', 'error');
        _isOnline = false;
      }
    } catch (e) {
      if (_isOnline) _addLog('Bridge connection failed', 'error');
      _isOnline = false;
    }
    notifyListeners();
  }

  void _addLog(String message, String type) {
    _activityLog.insert(0, {
      'time': DateTime.now().toIso8601String(),
      'message': message,
      'type': type,
    });
    if (_activityLog.length > 30) _activityLog.removeLast();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
