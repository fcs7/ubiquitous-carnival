import 'package:flutter/material.dart';
import 'package:muglia/widgets/app_drawer.dart';
import 'package:muglia/theme/muglia_theme.dart';

class MugliaScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const MugliaScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        surfaceTintColor: MugliaTheme.surface,
      ),
      drawer: const AppDrawer(),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
