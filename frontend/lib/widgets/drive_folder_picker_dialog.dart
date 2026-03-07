import 'package:flutter/material.dart';

import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';

/// Resultado da selecao de pasta do Drive.
class DriveFolderSelection {
  final String id;
  final String nome;
  DriveFolderSelection(this.id, this.nome);
}

/// Dialog para navegar e selecionar uma pasta do Google Drive.
///
/// Uso:
/// ```dart
/// final pasta = await showDialog<DriveFolderSelection>(
///   context: context,
///   builder: (_) => DriveFolderPickerDialog(api: api),
/// );
/// ```
class DriveFolderPickerDialog extends StatefulWidget {
  final ApiService api;
  final String? pastaInicialId;

  const DriveFolderPickerDialog({
    super.key,
    required this.api,
    this.pastaInicialId,
  });

  @override
  State<DriveFolderPickerDialog> createState() =>
      _DriveFolderPickerDialogState();
}

class _DriveFolderPickerDialogState extends State<DriveFolderPickerDialog> {
  List<dynamic> _items = [];
  final List<_BreadcrumbItem> _breadcrumbs = [];
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    if (widget.pastaInicialId != null) {
      _navegarPasta(widget.pastaInicialId!, 'Raiz');
    }
  }

  Future<void> _navegarPasta(String pastaId, String nome) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final items = await widget.api.listarPastaDrive(pastaId);
      setState(() {
        _items = items;
        _breadcrumbs.add(_BreadcrumbItem(pastaId, nome));
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  void _voltarPara(int index) {
    if (index >= _breadcrumbs.length - 1) return;
    final item = _breadcrumbs[index];
    setState(() {
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      _breadcrumbs.removeLast();
    });
    _navegarPasta(item.id, item.nome);
  }

  void _selecionarPastaAtual() {
    if (_breadcrumbs.isEmpty) return;
    final atual = _breadcrumbs.last;
    Navigator.of(context).pop(DriveFolderSelection(atual.id, atual.nome));
  }

  bool _ehPasta(Map<String, dynamic> item) =>
      item['mimeType'] == 'application/vnd.google-apps.folder';

  IconData _iconePorMime(String? mime) {
    if (mime == null) return Icons.insert_drive_file;
    if (mime.contains('folder')) return Icons.folder_rounded;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('image')) return Icons.image_rounded;
    if (mime.contains('spreadsheet') || mime.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (mime.contains('document') || mime.contains('word')) {
      return Icons.description_rounded;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Icons.slideshow_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _corPorMime(String? mime) {
    if (mime == null) return MugliaTheme.textMuted;
    if (mime.contains('folder')) return MugliaTheme.warning;
    if (mime.contains('pdf')) return MugliaTheme.error;
    if (mime.contains('image')) return MugliaTheme.accent;
    if (mime.contains('spreadsheet') || mime.contains('excel')) {
      return MugliaTheme.success;
    }
    if (mime.contains('document') || mime.contains('word')) {
      return MugliaTheme.info;
    }
    return MugliaTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar pasta do Drive'),
      content: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          children: [
            if (_breadcrumbs.isEmpty) _buildEntradaPastaId(),
            if (_breadcrumbs.isNotEmpty) ...[
              _buildBreadcrumbs(),
              const Divider(height: 1),
              // Botao de selecionar pasta atual
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: MugliaTheme.accent.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded,
                        size: 20, color: MugliaTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _breadcrumbs.last.nome,
                        style: TextStyle(
                          color: MugliaTheme.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selecionarPastaAtual,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Selecionar'),
                      style: TextButton.styleFrom(
                        foregroundColor: MugliaTheme.accent,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _carregando
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: MugliaTheme.primary))
                    : _erro != null
                        ? _buildErro()
                        : _items.isEmpty
                            ? const Center(
                                child: Text('Pasta vazia',
                                    style: TextStyle(
                                        color: MugliaTheme.textMuted)))
                            : _buildListaItems(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildEntradaPastaId() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_rounded,
                size: 48, color: MugliaTheme.primaryLight),
            const SizedBox(height: 16),
            Text(
              'Informe o ID da pasta raiz',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 350,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'ID da pasta do Google Drive',
                  prefixIcon: Icon(Icons.folder_open_rounded),
                ),
                onSubmitted: (id) {
                  if (id.trim().isNotEmpty) {
                    _navegarPasta(id.trim(), 'Raiz');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: MugliaTheme.surfaceVariant,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _breadcrumbs.length; i++) ...[
              if (i > 0)
                const Icon(Icons.chevron_right,
                    size: 16, color: MugliaTheme.textMuted),
              InkWell(
                onTap: i < _breadcrumbs.length - 1
                    ? () => _voltarPara(i)
                    : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    _breadcrumbs[i].nome,
                    style: TextStyle(
                      fontSize: 12,
                      color: i < _breadcrumbs.length - 1
                          ? MugliaTheme.primary
                          : MugliaTheme.textPrimary,
                      fontWeight: i == _breadcrumbs.length - 1
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListaItems() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i] as Map<String, dynamic>;
        final ehPasta = _ehPasta(item);
        final mime = item['mimeType'] as String?;

        return ListTile(
          dense: true,
          leading: Icon(_iconePorMime(mime), color: _corPorMime(mime), size: 28),
          title: Text(
            item['name'] ?? '',
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: ehPasta
              ? const Text('Pasta',
                  style: TextStyle(color: MugliaTheme.textMuted, fontSize: 11))
              : Text(
                  mime?.split('/').last ?? '',
                  style: const TextStyle(
                      color: MugliaTheme.textMuted, fontSize: 11),
                ),
          onTap: ehPasta
              ? () => _navegarPasta(item['id'], item['name'])
              : null,
          trailing: ehPasta
              ? const Icon(Icons.chevron_right,
                  size: 18, color: MugliaTheme.textMuted)
              : null,
        );
      },
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: MugliaTheme.error),
            const SizedBox(height: 12),
            Text(
              _erro!,
              style: const TextStyle(color: MugliaTheme.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbItem {
  final String id;
  final String nome;
  _BreadcrumbItem(this.id, this.nome);
}
