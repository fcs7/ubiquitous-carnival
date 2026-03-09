import 'package:flutter/material.dart';
import 'package:muglia/widgets/app_drawer.dart';
import 'package:muglia/theme/muglia_theme.dart';

class MugliaScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? endDrawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const MugliaScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.endDrawer,
    this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        surfaceTintColor: MugliaTheme.surface,
      ),
      drawer: const AppDrawer(),
      endDrawer: endDrawer,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
