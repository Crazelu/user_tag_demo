import 'package:flutter/material.dart';
import 'package:user_tag_demo/models/user.dart';

class SearchViewModel {
  late final ValueNotifier<List<User>> _users = ValueNotifier([]);
  ValueNotifier<List<User>> get users => _users;

  late final ValueNotifier<bool> _loading = ValueNotifier(false);
  ValueNotifier<bool> get loading => _loading;

  void _setLoading(bool val) {
    if (val != _loading.value) {
      _loading.value = val;
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;

    query = query.toLowerCase().trim();

    _users.value = [];
    _users.notifyListeners();

    _setLoading(true);

    await Future.delayed(const Duration(milliseconds: 250));

    final result = User.allUsers
        .where(
          (user) =>
              user.userName.toLowerCase().contains(query) ||
              user.fullName.toLowerCase().contains(query),
        )
        .toList();
    _users.value = result;
    _users.notifyListeners();
    _setLoading(false);
  }
}
