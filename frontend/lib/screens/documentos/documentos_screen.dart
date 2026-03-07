import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';
import 'package:muglia/services/api_service.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  // Drive
  List<dynamic> _driveItems = [];
  final List<_BreadcrumbItem> _breadcrumbs = [];
  bool _driveCarregando = false;
  String? _driveErro;

  // Busca
  final _buscaController = TextEditingController();
  List<dynamic> _buscaResultados = [];
  bool _buscando = false;

  // Vinculados
  List<dynamic> _processos = [];
  int? _processoSelecionado;
  List<dynamic> _documentosVinculados = [];
  bool _vinculadosCarregando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarProcessos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // ── Drive ──────────────────────────────────
  Future<void> _navegarPasta(String pastaId, String nome) async {
    setState(() {
      _driveCarregando = true;
      _driveErro = null;
    });
    try {
      final items = await _api.listarPastaDrive(pastaId);
      setState(() {
        _driveItems = items;
        _breadcrumbs.add(_BreadcrumbItem(pastaId, nome));
        _driveCarregando = false;
      });
    } catch (e) {
      setState(() {
        _driveErro = e.toString();
        _driveCarregando = false;
      });
    }
  }

  void _voltarPara(int index) {
    if (index >= _breadcrumbs.length - 1) return;
    final item = _breadcrumbs[index];
    setState(() {
      _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
    });
    // Recarrega removendo o ultimo breadcrumb para re-navegar
    setState(() => _breadcrumbs.removeLast());
    _navegarPasta(item.id, item.nome);
  }

  // ── Busca ──────────────────────────────────
  Future<void> _buscar() async {
    final q = _buscaController.text.trim();
    if (q.length < 2) return;
    setState(() => _buscando = true);
    try {
      final resultados = await _api.buscarDrive(q);
      setState(() {
        _buscaResultados = resultados;
        _buscando = false;
      });
    } catch (e) {
      setState(() => _buscando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na busca: $e')),
        );
      }
    }
  }

  // ── Processos / Vinculados ─────────────────
  Future<void> _carregarProcessos() async {
    try {
      final procs = await _api.getProcessos();
      setState(() => _processos = procs);
    } catch (_) {}
  }

  Future<void> _carregarVinculados(int processoId) async {
    setState(() => _vinculadosCarregando = true);
    try {
      final docs = await _api.getDocumentosProcesso(processoId);
      setState(() {
        _documentosVinculados = docs;
        _vinculadosCarregando = false;
      });
    } catch (e) {
      setState(() => _vinculadosCarregando = false);
    }
  }

  Future<void> _vincularAoProcesso(Map<String, dynamic> driveItem) async {
    if (_processos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum processo cadastrado')),
      );
      return;
    }

    final processoId = await showDialog<int>(
      context: context,
      builder: (ctx) => _DialogSelecionarProcesso(processos: _processos),
    );
    if (processoId == null) return;

    try {
      await _api.vincularDocumentoDrive({
        'drive_file_id': driveItem['id'],
        'drive_url': driveItem['webViewLink'] ?? '',
        'nome': driveItem['name'],
        'mime_type': driveItem['mimeType'],
        'tamanho_bytes': driveItem['size'] != null ? int.tryParse(driveItem['size']) : null,
        'processo_id': processoId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento vinculado com sucesso')),
        );
        if (_processoSelecionado == processoId) {
          _carregarVinculados(processoId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao vincular: $e')),
        );
      }
    }
  }

  Future<void> _desvincular(int documentoId) async {
    try {
      await _api.desvincularDocumento(documentoId);
      if (_processoSelecionado != null) {
        _carregarVinculados(_processoSelecionado!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento desvinculado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _abrirLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── UI Helpers ─────────────────────────────
  bool _ehPasta(Map<String, dynamic> item) =>
      item['mimeType'] == 'application/vnd.google-apps.folder';

  IconData _iconePorMime(String? mime) {
    if (mime == null) return Icons.insert_drive_file;
    if (mime.contains('folder')) return Icons.folder_rounded;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('image')) return Icons.image_rounded;
    if (mime.contains('spreadsheet') || mime.contains('excel')) return Icons.table_chart_rounded;
    if (mime.contains('document') || mime.contains('word')) return Icons.description_rounded;
    if (mime.contains('presentation') || mime.contains('powerpoint')) return Icons.slideshow_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _corPorMime(String? mime) {
    if (mime == null) return MugliaTheme.textMuted;
    if (mime.contains('folder')) return MugliaTheme.warning;
    if (mime.contains('pdf')) return MugliaTheme.error;
    if (mime.contains('image')) return MugliaTheme.accent;
    if (mime.contains('spreadsheet') || mime.contains('excel')) return MugliaTheme.success;
    if (mime.contains('document') || mime.contains('word')) return MugliaTheme.info;
    return MugliaTheme.textMuted;
  }

  String _formatarTamanho(dynamic size) {
    if (size == null) return '';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Documentos',
      body: Column(
        children: [
          Container(
            color: MugliaTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: MugliaTheme.primary,
              labelColor: MugliaTheme.primary,
              unselectedLabelColor: MugliaTheme.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.folder_rounded), text: 'Google Drive'),
                Tab(icon: Icon(Icons.search_rounded), text: 'Buscar'),
                Tab(icon: Icon(Icons.link_rounded), text: 'Vinculados'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDriveTab(),
                _buildBuscaTab(),
                _buildVinculadosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Drive ──────────────────────────────
  Widget _buildDriveTab() {
    if (_breadcrumbs.isEmpty) {
      return _buildDriveVazio();
    }
    return Column(
      children: [
        _buildBreadcrumbs(),
        const Divider(height: 1),
        Expanded(
          child: _driveCarregando
              ? const Center(child: CircularProgressIndicator())
              : _driveErro != null
                  ? _buildErro(_driveErro!)
                  : _driveItems.isEmpty
                      ? _buildVazio('Pasta vazia')
                      : _buildListaArquivos(_driveItems, comVincular: true),
        ),
      ],
    );
  }

  Widget _buildDriveVazio() {
    return Center(
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
                Icons.cloud_rounded,
                size: 48,
                color: MugliaTheme.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Google Drive',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Informe o ID da pasta raiz para navegar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MugliaTheme.textMuted,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 400,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'ID da pasta raiz do Google Drive',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MugliaTheme.surfaceVariant,
      child: Row(
        children: [
          for (int i = 0; i < _breadcrumbs.length; i++) ...[
            if (i > 0) const Icon(Icons.chevron_right, size: 16, color: MugliaTheme.textMuted),
            InkWell(
              onTap: i < _breadcrumbs.length - 1 ? () => _voltarPara(i) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  _breadcrumbs[i].nome,
                  style: TextStyle(
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
    );
  }

  // ── Tab Busca ──────────────────────────────
  Widget _buildBuscaTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscaController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar arquivos no Drive...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _buscando ? null : _buscar,
                child: _buscando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Buscar'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buscaResultados.isEmpty
              ? _buildVazio('Busque por nome de arquivo')
              : _buildListaArquivos(_buscaResultados, comVincular: true),
        ),
      ],
    );
  }

  // ── Tab Vinculados ─────────────────────────
  Widget _buildVinculadosTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<int>(
            value: _processoSelecionado,
            decoration: const InputDecoration(
              hintText: 'Selecione um processo',
              prefixIcon: Icon(Icons.gavel_rounded),
            ),
            items: _processos.map((p) {
              return DropdownMenuItem<int>(
                value: p['id'],
                child: Text(p['cnj'] ?? 'Processo #${p['id']}', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (id) {
              setState(() => _processoSelecionado = id);
              if (id != null) _carregarVinculados(id);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _vinculadosCarregando
              ? const Center(child: CircularProgressIndicator())
              : _processoSelecionado == null
                  ? _buildVazio('Selecione um processo para ver documentos vinculados')
                  : _documentosVinculados.isEmpty
                      ? _buildVazio('Nenhum documento vinculado a este processo')
                      : _buildListaVinculados(),
        ),
      ],
    );
  }

  Widget _buildListaVinculados() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _documentosVinculados.length,
      itemBuilder: (ctx, i) {
        final doc = _documentosVinculados[i];
        final mime = doc['mime_type'] as String?;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(_iconePorMime(mime), color: _corPorMime(mime), size: 32),
            title: Text(doc['nome'] ?? 'Sem nome'),
            subtitle: Text(
              '${doc['categoria'] ?? 'sem categoria'} — ${doc['origem'] == 'drive' ? 'Google Drive' : 'Local'}',
              style: const TextStyle(color: MugliaTheme.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (doc['drive_url'] != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    tooltip: 'Abrir no Drive',
                    onPressed: () => _abrirLink(doc['drive_url']),
                  ),
                IconButton(
                  icon: const Icon(Icons.link_off_rounded, size: 20, color: MugliaTheme.error),
                  tooltip: 'Desvincular',
                  onPressed: () => _desvincular(doc['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Compartilhados ─────────────────────────
  Widget _buildListaArquivos(List<dynamic> items, {bool comVincular = false}) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i] as Map<String, dynamic>;
        final ehPasta = _ehPasta(item);
        final mime = item['mimeType'] as String?;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(_iconePorMime(mime), color: _corPorMime(mime), size: 32),
            title: Text(item['name'] ?? ''),
            subtitle: ehPasta
                ? const Text('Pasta', style: TextStyle(color: MugliaTheme.textMuted))
                : Text(
                    _formatarTamanho(item['size']),
                    style: const TextStyle(color: MugliaTheme.textMuted),
                  ),
            onTap: ehPasta ? () => _navegarPasta(item['id'], item['name']) : null,
            trailing: ehPasta
                ? const Icon(Icons.chevron_right, color: MugliaTheme.textMuted)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (comVincular)
                        IconButton(
                          icon: const Icon(Icons.link_rounded, size: 20, color: MugliaTheme.primary),
                          tooltip: 'Vincular a processo',
                          onPressed: () => _vincularAoProcesso(item),
                        ),
                      if (item['webViewLink'] != null)
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 20),
                          tooltip: 'Abrir no Drive',
                          onPressed: () => _abrirLink(item['webViewLink']),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildVazio(String mensagem) {
    return Center(
      child: Text(mensagem, style: const TextStyle(color: MugliaTheme.textMuted)),
    );
  }

  Widget _buildErro(String erro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: MugliaTheme.error),
            const SizedBox(height: 16),
            Text(erro, style: const TextStyle(color: MugliaTheme.error), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Dialog para selecionar processo ──────────
class _DialogSelecionarProcesso extends StatelessWidget {
  final List<dynamic> processos;
  const _DialogSelecionarProcesso({required this.processos});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vincular a qual processo?'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: ListView.builder(
          itemCount: processos.length,
          itemBuilder: (ctx, i) {
            final p = processos[i];
            return ListTile(
              leading: const Icon(Icons.gavel_rounded, color: MugliaTheme.primary),
              title: Text(p['cnj'] ?? ''),
              subtitle: Text(p['classe_nome'] ?? '', style: const TextStyle(color: MugliaTheme.textMuted)),
              onTap: () => Navigator.of(context).pop(p['id']),
            );
          },
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
}

// ── Model auxiliar ───────────────────────────
class _BreadcrumbItem {
  final String id;
  final String nome;
  _BreadcrumbItem(this.id, this.nome);
}
