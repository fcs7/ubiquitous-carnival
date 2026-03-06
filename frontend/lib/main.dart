import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/router.dart';
import 'package:muglia/services/api_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: const MugliaApp(),
    ),
  );
}

class MugliaApp extends StatelessWidget {
  const MugliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Muglia - Gestao Juridica',
      debugShowCheckedModeBanner: false,
      theme: MugliaTheme.darkTheme,
      routerConfig: router,
    );
  }
}
