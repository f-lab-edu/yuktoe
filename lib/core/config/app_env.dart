import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  const AppEnv._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

  static String get appScheme => dotenv.env['APP_SCHEME']!;
  static String get appAuthCallbackHost =>
      dotenv.env['APP_AUTH_CALLBACK_HOST']!;

  static String get authRedirectUri => '$appScheme://$appAuthCallbackHost';

  static String get kakaoNativeAppKey => dotenv.env['KAKAO_NATIVE_APP_KEY']!;
  static String get googleWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID']!;
  static String get googleIOSClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID']!;
  static String get googleAndroidClientId =>
      dotenv.env['GOOGLE_ANDROID_CLIENT_ID']!;
}
