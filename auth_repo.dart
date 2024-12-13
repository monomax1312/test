 Future<ResponseAPI<UserData>> providerAuthorization({
  required String provider,
  required String notifToken,
  required String language,
  String? userId,
  String? accessToken,
  String? idToken,
}) async {
  final path = 'auth/${provider}_login';
  Map<String, dynamic> body = {
    'notification_token': notifToken,
    'lang': language,
    'device': DeviceInfo.instance.name.toLowerCase(),
  };
  switch (provider) {
    case 'google':
      if (idToken != null) {
        body['id_token'] = idToken;
      }
      break;
    case 'vk' || 'ok':
      if (accessToken != null) {
        body['access_token'] = accessToken;
      }
      break;
    default:
      throw Exception('Неизвестный провайдер: $provider');
  }
  final response = await client.post(
    uriWith(path: path),
    body: body,
  );
  return wrapResponse(
    response,
    (Map<String, Object?> data) => (
      UserProfile.fromJson(data['user']! as Map<String, dynamic>),
      data['token']! as String,
    ),
    castNested: false,
  );
}
