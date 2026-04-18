import 'package:hive_flutter/hive_flutter.dart';

import '../../features/history/data/models/history_entry_model.dart';
import '../constants/app_constants.dart';

class HiveService {
  HiveService._();

  static Box<HistoryEntryModel> get historyBox =>
      Hive.box<HistoryEntryModel>(AppConstants.historyBoxName);

  static Future<void> openBoxes() async {
    await Hive.openBox<HistoryEntryModel>(AppConstants.historyBoxName);
  }
}
