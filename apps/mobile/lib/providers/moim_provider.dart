import 'package:flutter/material.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';
import '../services/api_client.dart';

class MoimProvider extends ChangeNotifier {
  List<MoimResponse> _moims = [];
  MoimResponse? _selectedMoim;
  List<ParticipantResponse> _participants = [];
  bool _loading = false;
  String? _error;

  List<MoimResponse> get moims => _moims;
  MoimResponse? get selectedMoim => _selectedMoim;
  List<ParticipantResponse> get participants => _participants;
  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> loadMyMoims() async {
    _setLoading(true);
    _error = null;
    try {
      _moims = await ApiClient.getMyMoims();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<MoimResponse?> loadMoim(int moimId) async {
    _setLoading(true);
    _error = null;
    try {
      _selectedMoim = await ApiClient.getMoim(moimId);
      notifyListeners();
      return _selectedMoim;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadParticipants(int moimId) async {
    _setLoading(true);
    _error = null;
    try {
      _participants = await ApiClient.getParticipants(moimId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<MoimResponse?> createMoim(Map<String, dynamic> data) async {
    _setLoading(true);
    _error = null;
    try {
      final moim = await ApiClient.createMoim(data);
      _moims.insert(0, moim);
      notifyListeners();
      return moim;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MoimResponse?> joinMoim({
    required String inviteCode,
    String? refundBank,
    String? refundAccountNumber,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final moim = await ApiClient.joinMoim(
        inviteCode: inviteCode,
        refundBank: refundBank,
        refundAccountNumber: refundAccountNumber,
      );
      _moims.insert(0, moim);
      notifyListeners();
      return moim;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<ParticipantResponse>> settle(int moimId) async {
    _setLoading(true);
    _error = null;
    try {
      final result = await ApiClient.settle(moimId);
      _participants = result;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      return [];
    } finally {
      _setLoading(false);
    }
  }
}
