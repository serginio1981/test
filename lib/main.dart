import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/storage/hive_service.dart';
import 'features/history/data/models/history_entry_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  Hive.registerAdapter(HistoryEntryModelAdapter());
  await HiveService.openBoxes();

  runApp(const ProviderScope(child: BirdSoundIdentifierApp()));
}
