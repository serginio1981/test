import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../domain/entities/history_entry.dart';

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  HistoryNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;

  void _load() {
    final datasource = _ref.read(historyDatasourceProvider);
    state = datasource.getAll();
  }

  void refresh() => _load();

  Future<void> delete(String id) async {
    final datasource = _ref.read(historyDatasourceProvider);
    await datasource.delete(id);
    state = datasource.getAll();
  }

  Future<void> clearAll() async {
    final datasource = _ref.read(historyDatasourceProvider);
    await datasource.clearAll();
    state = [];
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  return HistoryNotifier(ref);
});
