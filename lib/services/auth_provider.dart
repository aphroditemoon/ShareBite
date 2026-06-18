import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        final res = await ApiService.getMe();
        if (res['success'] == true) {
          _user = UserModel.fromJson(res['data']['user']);
        }
      }
    } catch (_) {
      await ApiService.clearToken();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final res = await ApiService.login(email, password);
      if (res['success'] == true) {
        await ApiService.saveToken(res['data']['token']);
        _user = UserModel.fromJson(res['data']['user']);
        _isLoading = false; notifyListeners();
        return true;
      }
    } catch (e) { _error = e.toString(); }
    _isLoading = false; notifyListeners();
    return false;
  }

  Future<bool> register(String name, String email, String password, {String? phone}) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final res = await ApiService.register(name, email, password, phone: phone);
      if (res['success'] == true) {
        await ApiService.saveToken(res['data']['token']);
        _user = UserModel.fromJson(res['data']['user']);
        _isLoading = false; notifyListeners();
        return true;
      }
    } catch (e) { _error = e.toString(); }
    _isLoading = false; notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }

  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }
}
