import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/config/app_env.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository.dart';
import 'package:yuktoe/data/repositories/auth_repository/auth_repository_impl.dart';
import 'package:yuktoe/data/services/auth_service/auth_service.dart';
import 'package:yuktoe/data/services/auth_service/supabase_auth_service.dart';

List<SingleChildWidget> buildDependencies() {
  return [
    Provider<SupabaseClient>(create: (_) => Supabase.instance.client),
    Provider<AuthService>(
      create: (context) => SupabaseAuthService(
        client: context.read<SupabaseClient>(),
        redirectTo: AppEnv.authRedirectUri,
      ),
    ),
    Provider<AuthRepository>(
      create: (context) => AuthRepositoryImpl(context.read<AuthService>()),
    ),
  ];
}
