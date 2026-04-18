import '../../../record/domain/entities/recording_session.dart';
import '../entities/identified_bird.dart';

abstract class IdentificationRepository {
  Future<List<IdentifiedBird>> identify(RecordingSession session);
}
