import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../../record/domain/entities/recording_session.dart';
import '../../domain/entities/identified_bird.dart';

final identificationProvider = FutureProvider.family<List<IdentifiedBird>,
    RecordingSession>((ref, session) async {
  final usecase = ref.read(identifyBirdUsecaseProvider);
  return usecase.execute(session);
});
