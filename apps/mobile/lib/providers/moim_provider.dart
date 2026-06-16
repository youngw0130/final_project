import 'package:flutter/material.dart';
import '../models/moim_response.dart';
import '../models/participant_response.dart';
import '../models/payment_response.dart';
import '../services/api_client.dart';

class MoimProvider extends ChangeNotifier {
  List<MoimResponse> _moims = [];
  MoimResponse? _selectedMoim;
  List<ParticipantResponse> _participants = [];
  List<PaymentResponse> _payments = [];
  bool _loading = false;
  String? _error;

  List<MoimResponse> get moims => _moims;
  MoimResponse? get selectedMoim => _selectedMoim;
  List<ParticipantResponse> get participants => _participants;
  List<PaymentResponse> get payments => _payments;
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
      debugPrint('[MoimProvider] loaded ${_moims.length} moims');
    } catch (e, st) {
      _error = e.toString();
      debugPrint('[MoimProvider] loadMyMoims error: $e\n$st');
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

  Future<void> loadPayments(int moimId) async {
    _error = null;
    try {
      _payments = await ApiClient.getPayments(moimId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> loadParticipants(int moimId) async {
    _error = null;
    try {
      _participants = await ApiClient.getParticipants(moimId);
      debugPrint('[MoimProvider] loaded ${_participants.length} participants for moim $moimId: ${_participants.map((p) => p.username).toList()}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('[MoimProvider] loadParticipants error: $e');
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

  Future<bool> cancelMoim(int moimId) async {
    _setLoading(true);
    _error = null;
    try {
      await ApiClient.cancelMoim(moimId);
      _moims.removeWhere((m) => m.id == moimId);
      if (_selectedMoim?.id == moimId) _selectedMoim = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
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
