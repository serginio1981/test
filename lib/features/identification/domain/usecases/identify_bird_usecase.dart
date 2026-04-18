import '../../../record/domain/entities/recording_session.dart';
import '../entities/identified_bird.dart';
import '../repositories/identification_repository.dart';

class IdentifyBirdUsecase {
  const IdentifyBirdUsecase(this._repository);

  final IdentificationRepository _repository;

  Future<List<IdentifiedBird>> execute(RecordingSession session) {
    return _repository.identify(session);
  }
}
