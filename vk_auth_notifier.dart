
class VkAuthNotifier extends AsyncNotifier<void> with Logging {
  static final i = AsyncNotifierProvider<VkAuthNotifier, void>(
    () => VkAuthNotifier(appId: '52599851'),
    name: '$VkAuthNotifier',
  );

  late final AuthRepo _authRepo;
  late final AuthNotifier _authNotifier;
  late final StorageNotifier _profileStorage;
  late final PushToken? _pushNotif;
  late final VKLogin _vkLogin;
  bool _isSdkInitialized = false;

  final String appId;
  VkAuthNotifier({required this.appId}) : _vkLogin = VKLogin(debug: true);

  @override
  String get whoLog => '🔵VKAuthNotifier';

  @override
  Future<void> build() async {
    _authRepo = ref.watch(authRepoProvider);
    _authNotifier = ref.read(AuthNotifier.i.notifier);
    _profileStorage = ref.read(StorageNotifier.profile);
    _pushNotif = await ref.watch(PushNotifService.i.future);
  }

  Future<void> initializeSdk() async {
    try {
      lgl.i('Инициализация VK SDK...');
      final result = await _vkLogin.initSdk(
        scope: [VKScope.email, VKScope.offline],
      );
      if (!result.isValue) {
        lgl.e('Ошибка инициализации VK SDK.');
        throw Exception('Инициализация VK SDK не удалась.');
      }
      _isSdkInitialized = true;
      lgl.i('VK SDK успешно инициализирован.');
    } catch (e) {
      lgl.e('Ошибка при инициализации VK SDK: $e');
      throw Exception('Ошибка при инициализации VK SDK');
    }
  }

  Future<void> signInWithVk() async {
    await initializeSdk();
    try {
      lgl.i('Попытка авторизации через VK...');
      if (!_isSdkInitialized) {
        lgl.e('VK SDK не инициализирован.');
        throw Exception('VK SDK не инициализирован.');
      }
      final isLoggedIn = await _vkLogin.isLoggedIn;
      if (isLoggedIn) {
        lgl.i('Пользователь уже авторизован.');
        return;
      }
      final result = await _vkLogin.logIn(scope: [
        VKScope.email,
        VKScope.offline,
        VKScope.docs,
        VKScope.notifications
      ]);
      if (!result.isValue || result.asValue?.value.isCanceled == true) {
        throw Exception(
            'Авторизация отменена пользователем или произошла ошибка.');
      }
      final vkResult = result.asValue!.value;
      final accessToken = vkResult.accessToken!.token;
      final vkUserId = vkResult.accessToken!.userId;
      lgl.i('VK AccessToken получен: $accessToken');
      await _sendAuthDataToServer(
        provider: 'vk',
        accessToken: accessToken,
        userId: vkUserId.toString(),
      );
    } catch (e) {
      lgl.e('Ошибка авторизации через VK: $e');
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> _sendAuthDataToServer({
    required String provider,
    required String accessToken,
    String? userId,
  }) async {
    try {
      final response = await _authRepo.providerAuthorization(
        provider: provider,
        accessToken: accessToken,
        language: LocaleSettings.currentLocale.languageCode,
        notifToken: _pushNotif?.token ?? 'undefined',
      );
      switch (response) {
        case ResponseDataAPI(data: (final profile, final token)):
          await _profileStorage.set(ProfileCard.authToken, token);
          _authNotifier.updateToken(token);
          state = AsyncData(AuthState.authorized(profile));
          lgl.i('Пользователь успешно авторизован через VK.');
          break;
        case ResponseErrorAPI(:final message):
          lgl.e('Ошибка при авторизации через VK: $message');
          state = AsyncError(message, StackTrace.current);
          break;
        default:
          lgl.e('Неизвестная ошибка авторизации через VK.');
          throw Exception('Неизвестная ошибка авторизации через VK.');
      }
    } catch (e) {
      lgl.e('Ошибка при отправке данных на сервер: $e');
      state = AsyncError(e, StackTrace.current);
    }
  }
}
