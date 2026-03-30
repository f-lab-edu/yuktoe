import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yuktoe/core/config/app_env.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository.dart';
import 'package:yuktoe/data/repositories/baby_registration_repository/baby_registration_repository_impl.dart';
import 'package:yuktoe/data/services/baby_registration_service/baby_registration_service.dart';
import 'package:yuktoe/data/services/baby_registration_service/supabase_baby_registration_service.dart';
import 'package:yuktoe/routing/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseClient = Supabase.instance.client;
    final BabyRegistrationService babyRegistrationService =
        SupabaseBabyRegistrationService(client: supabaseClient);

    return Provider<BabyRegistrationRepository>(
      create: (_) => BabyRegistrationRepositoryImpl(babyRegistrationService),
      child: MaterialApp.router(
        title: '내꿈은육퇴',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B7FFF)),
        ),
        routerConfig: router,
      ),
    );
  }
}
