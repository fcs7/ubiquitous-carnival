import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Documentos',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: MugliaTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 48,
                  color: MugliaTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Documentos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: MugliaTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Modulo de documentos em desenvolvimento',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MugliaTheme.textMuted,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
