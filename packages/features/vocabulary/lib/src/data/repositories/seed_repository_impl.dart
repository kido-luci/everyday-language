import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/seed_repository.dart';
import '../local/seed_local_data_source.dart';
import '../seed/seed_pack_loader.dart';

@LazySingleton(as: SeedRepository)
class SeedRepositoryImpl implements SeedRepository {
  const SeedRepositoryImpl(this._loader, this._local);

  final SeedPackLoader _loader;
  final SeedLocalDataSource _local;

  @override
  Future<Result<int>> importBundledPack() async {
    final pack = await _loader.load();
    if (pack == null) return const Ok(0);

    // Checked before parsing would have mattered, but the loader has already
    // read the asset by now and this is the cheap half. It saves opening a
    // transaction on every launch after the first.
    if (await _local.hasImported(pack.id)) return const Ok(0);

    return Ok(await _local.importPack(pack, now: DateTime.now().toUtc()));
  }
}
