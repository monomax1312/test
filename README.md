import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rooli/src/core/utils/logging.dart';
import 'package:rooli/src/features/auth/domain/auth_notifier.dart';
import 'package:rooli/src/features/auth/domain/notifiers.dart';
import '../../auth/data/auth_repo.dart';
import '../models/social_networks_settings.dart';

class SocialNetworksSettingsNotifier extends AsyncNotifier<SocialNetworksSettings> {
  static final i = AsyncNotifierProvider<SocialNetworksSettingsNotifier, SocialNetworksSettings>(
    SocialNetworksSettingsNotifier.new,
    name: '$SocialNetworksSettingsNotifier',
  );

  late AuthRepo authRepo;

  @override
  FutureOr<SocialNetworksSettings> build() async {
    authRepo = ref.watch(authRepoProvider);
    return await fetchSocialNetworksSettings();
  }

  Future<SocialNetworksSettings> fetchSocialNetworksSettings() async {
    try {
      lgl.i('Попытка получить настройки соцсетей');
      final res = await authRepo.getSocialNetworksSettings();
      final data = res.asData();
      if (data != null) {
        lgl.i('Настройки соцсетей успешно получены.');
        return data;
      } else {
        throw Exception('Не удалось получить настройки соцсетей.');
      }
    } catch (e, s) {
      lgl.e('Ошибка при получении настроек соцсетей: $e', s);
      rethrow;
    }
  }

  Future<void> saveSocialNetworksSettings(
      SocialNetworksSettings socialNetworksSettings
  ) async {
    try {
      lgl.i(
        'Сохранение настроек : $socialNetworksSettings',
      );
      state = await AsyncValue.guard(() async {
        final res = await authRepo.saveSocialNetworksSettings(
            socialNetworksSettings
        );
        final success = res.asData();
        if (success) {
          lgl.i('Настройки соцсетей успешно сохранены.');
          ref.invalidate(AuthNotifier.i);
          return await fetchSocialNetworksSettings();
        } else {
          throw Exception('Ошибка сохранения настроек соцсетей');
        }
      });
    } catch (e, s) {
      lgl.e('Ошибка при сохранении настроек соцсетей: $e', s);
      rethrow;
    }
  }

  Future<SocialNetworksSettings?> getSocialNetworksSettings() async {
    final currentState = state;
    if (currentState is AsyncData<SocialNetworksSettings>) {
      return currentState.value;
    } else {
      try {
        final settings = await fetchSocialNetworksSettings();
        state = AsyncValue.data(settings);
        return settings;
      } catch (e, s) {
        lgl.e('Ошибка при запросе настроек соцсетей: $e', s);
        return null;
      }
    }
  }
}
