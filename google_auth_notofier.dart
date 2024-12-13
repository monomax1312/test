
class GoogleAuthNotifier extends AsyncNotifier<void> with Logging {
  static final i = AsyncNotifierProvider<GoogleAuthNotifier, void>(
    GoogleAuthNotifier.new,
    name: '$GoogleAuthNotifier',
  );
  late final AuthRepo _authRepo;
  late final AuthNotifier _authNotifier;
  late final StorageNotifier _profileStorage;
  late final PushToken? _pushNotif;
  GoogleSignIn? _googleSignIn;

  @override
  String get whoLog => '🟢GoogleAuthNotifier';

  @override
  Future<void> build() async {
    _authRepo = ref.watch(authRepoProvider);
    _authNotifier = ref.read(AuthNotifier.i.notifier);
    _profileStorage = ref.read(StorageNotifier.profile);
    _pushNotif = await ref.watch(PushNotifService.i.future);
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile', 'openid'],
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      state = const AsyncLoading();
      _googleSignIn ??= GoogleSignIn(
        scopes: ['email', 'profile', 'openid'],
      );
      lgl.i('GoogleSignIn инициализирован');
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      lgl.i('Результат: $googleUser');
      if (googleUser == null) {
        throw Exception('Авторизация Google отменена пользователем');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Не удалось получить Google ID токен');
      }

      final response = await _authRepo.providerAuthorization(
        provider: 'google',
        idToken: idToken,
        language: LocaleSettings.currentLocale.languageCode,
        notifToken: _pushNotif?.token ?? 'undefined',
      );
      switch (response) {
        case ResponseDataAPI(data: (final profile , final token)):
          await _profileStorage.set(ProfileCard.authToken, token);
          _authNotifier.updateToken(token);
          state = AsyncData(AuthState.authorized(profile));

        case ResponseErrorAPI(:final message):
          state = AsyncError(message, StackTrace.current);
          break;
        default:
          lgl.e('❌Google авторизация неуспешна!');
      }
    } catch (e) {
      lgl.e('Ошибка авторизации через Google: $e');
      state = AsyncError(e, StackTrace.current);
    }
  }
}
