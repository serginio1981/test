import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/bird_detail/data/datasources/ebird_sightings_datasource.dart';
import '../../features/bird_detail/data/datasources/inaturalist_datasource.dart';
import '../../features/bird_detail/data/datasources/wikipedia_datasource.dart';
import '../../features/bird_detail/data/repositories/bird_detail_repository_impl.dart';
import '../../features/history/data/datasources/history_local_datasource.dart';
import '../../features/history/domain/usecases/save_identification_usecase.dart';
import '../../features/identification/data/datasources/birdnet_remote_datasource.dart';
import '../../features/identification/data/repositories/identification_repository_impl.dart';
import '../../features/identification/domain/usecases/identify_bird_usecase.dart';
import '../../features/record/data/datasources/audio_recorder_datasource.dart';
import '../../features/record/data/repositories/audio_repository_impl.dart';
import '../../features/record/domain/repositories/audio_repository.dart';

// ── Record ──────────────────────────────────────────────────────────────────

final audioRecorderDatasourceProvider = Provider(
  (ref) => AudioRecorderDatasource(),
);

final audioRepositoryProvider = Provider<AudioRepository>(
  (ref) => AudioRepositoryImpl(ref.watch(audioRecorderDatasourceProvider)),
);

// ── Identification ───────────────────────────────────────────────────────────

final birdNetDatasourceProvider = Provider(
  (ref) => BirdNetRemoteDatasource(),
);

final identificationRepositoryProvider = Provider(
  (ref) => IdentificationRepositoryImpl(ref.watch(birdNetDatasourceProvider)),
);

final identifyBirdUsecaseProvider = Provider(
  (ref) => IdentifyBirdUsecase(ref.watch(identificationRepositoryProvider)),
);

// ── Bird Detail ──────────────────────────────────────────────────────────────

final wikipediaDatasourceProvider = Provider(
  (ref) => WikipediaDatasource(),
);

final iNatDatasourceProvider = Provider(
  (ref) => INaturalistDatasource(),
);

final eBirdDatasourceProvider = Provider(
  (ref) => EBirdSightingsDatasource(),
);

final birdDetailRepositoryProvider = Provider(
  (ref) => BirdDetailRepository(
    wikipedia: ref.watch(wikipediaDatasourceProvider),
    iNat: ref.watch(iNatDatasourceProvider),
    eBird: ref.watch(eBirdDatasourceProvider),
  ),
);

// ── History ──────────────────────────────────────────────────────────────────

final historyDatasourceProvider = Provider(
  (ref) => HistoryLocalDatasource(),
);

final saveIdentificationUsecaseProvider = Provider(
  (ref) => SaveIdentificationUsecase(ref.watch(historyDatasourceProvider)),
);
