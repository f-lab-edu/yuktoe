import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/config/app_env.dart';
import 'package:yuktoe/data/local/app_local_storage.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository_impl.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository_impl.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository.dart';
import 'package:yuktoe/data/repositories/analytics_repository/analytics_repository_impl.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository.dart';
import 'package:yuktoe/data/repositories/baby_repository/baby_repository_impl.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository.dart';
import 'package:yuktoe/data/repositories/chat_repository/chat_repository_impl.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository.dart';
import 'package:yuktoe/data/repositories/record_repository/record_repository_impl.dart';
import 'package:yuktoe/data/services/auth_service/auth_service.dart';
import 'package:yuktoe/data/services/auth_service/supabase_auth_service.dart';
import 'package:yuktoe/data/services/baby_registration_service/baby_registration_service.dart';
import 'package:yuktoe/data/services/baby_registration_service/supabase_baby_registration_service.dart';
import 'package:yuktoe/data/services/analytics_service/analytics_service.dart';
import 'package:yuktoe/data/services/analytics_service/supabase_analytics_service.dart';
import 'package:yuktoe/data/services/baby_service/baby_service.dart';
import 'package:yuktoe/data/services/baby_service/supabase_baby_service.dart';
import 'package:yuktoe/data/services/chat_service/chat_service.dart';
import 'package:yuktoe/data/services/chat_service/supabase_chat_service.dart';
import 'package:yuktoe/data/services/record_service/record_service.dart';
import 'package:yuktoe/data/services/record_service/supabase_record_service.dart';
import 'package:yuktoe/presentation/common/current_baby_controller.dart';

List<SingleChildWidget> buildDependencies({
  required SharedPreferences prefs,
}) {
  return [
    Provider<SupabaseClient>(create: (_) => Supabase.instance.client),
    Provider<SharedPreferences>(create: (_) => prefs),
    Provider<AppLocalStorage>(
      create: (context) => AppLocalStorage(context.read<SharedPreferences>()),
    ),
    ChangeNotifierProvider<CurrentBabyController>(
      create: (context) =>
          CurrentBabyController(context.read<AppLocalStorage>()),
    ),
    Provider<AuthService>(
      create: (context) => SupabaseAuthService(
        client: context.read<SupabaseClient>(),
        redirectTo: AppEnv.authRedirectUri,
      ),
    ),
    Provider<AuthRepository>(
      create: (context) => AuthRepositoryImpl(context.read<AuthService>()),
    ),
    Provider<BabyService>(
      create: (context) =>
          SupabaseBabyService(client: context.read<SupabaseClient>()),
    ),
    Provider<BabyRepository>(
      create: (context) => BabyRepositoryImpl(context.read<BabyService>()),
    ),
    Provider<RecordService>(
      create: (context) =>
          SupabaseRecordService(client: context.read<SupabaseClient>()),
    ),
    Provider<RecordRepository>(
      create: (context) =>
          RecordRepositoryImpl(context.read<RecordService>()),
    ),
    Provider<BabyRegistrationService>(
      create: (context) => SupabaseBabyRegistrationService(
        client: context.read<SupabaseClient>(),
      ),
    ),
    Provider<BabyRegistrationRepository>(
      create: (context) => BabyRegistrationRepositoryImpl(
        context.read<BabyRegistrationService>(),
      ),
    ),
    Provider<AnalyticsService>(
      create: (context) =>
          SupabaseAnalyticsService(client: context.read<SupabaseClient>()),
    ),
    Provider<AnalyticsRepository>(
      create: (context) =>
          AnalyticsRepositoryImpl(context.read<AnalyticsService>()),
    ),
    Provider<ChatService>(
      create: (context) =>
          SupabaseChatService(client: context.read<SupabaseClient>()),
    ),
    Provider<ChatRepository>(
      create: (context) => ChatRepositoryImpl(
        context.read<ChatService>(),
        context.read<AppLocalStorage>(),
      ),
    ),
  ];
}
