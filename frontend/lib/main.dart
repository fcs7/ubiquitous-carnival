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
      child: const EscritorioVirtualApp(),
    ),
  );
}

class EscritorioVirtualApp extends StatelessWidget {
  const EscritorioVirtualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Escritorio Virtual',
      debugShowCheckedModeBanner: false,
      theme: MugliaTheme.darkTheme,
      routerConfig: router,
    );
  }
}
