import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  // Filtros
  String _filtroTipo = 'todos';
  String _filtroCategoria = 'todos';

  // Dados mock
  final List<Map<String, String>> _mockDocs = [
    {
      'nome': 'Modelo Peticao Inicial.docx',
      'tipo': 'modelo',
      'categoria': 'peticao',
      'mime': 'application/docx',
      'data': '2026-03-01',
    },
    {
      'nome': 'Contestacao Proc 0001234.pdf',
      'tipo': 'gerado',
      'categoria': 'contestacao',
      'mime': 'application/pdf',
      'data': '2026-03-03',
    },
    {
      'nome': 'Recurso Ordinario - Silva.pdf',
      'tipo': 'upload',
      'categoria': 'recurso',
      'mime': 'application/pdf',
      'data': '2026-02-28',
    },
    {
      'nome': 'Agravo de Instrumento.docx',
      'tipo': 'modelo',
      'categoria': 'agravo',
      'mime': 'application/docx',
      'data': '2026-02-25',
    },
    {
      'nome': 'Procuracao Ad Judicia.pdf',
      'tipo': 'gerado',
      'categoria': 'outros',
      'mime': 'application/pdf',
      'data': '2026-03-04',
    },
    {
      'nome': 'Comprovante Residencia.jpg',
      'tipo': 'upload',
      'categoria': 'outros',
      'mime': 'image/jpeg',
      'data': '2026-02-20',
    },
    {
      'nome': 'Modelo Contestacao Trabalhista.docx',
      'tipo': 'modelo',
      'categoria': 'contestacao',
      'mime': 'application/docx',
      'data': '2026-03-02',
    },
  ];

  List<Map<String, String>> get _docsFiltrados {
    return _mockDocs.where((doc) {
      final tipoOk = _filtroTipo == 'todos' || doc['tipo'] == _filtroTipo;
      final catOk =
          _filtroCategoria == 'todos' || doc['categoria'] == _filtroCategoria;
      return tipoOk && catOk;
    }).toList();
  }

  IconData _iconeParaMime(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('doc') || mime.contains('word')) return Icons.description;
    if (mime.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _corParaMime(String mime) {
    if (mime.contains('pdf')) return MugliaTheme.error;
    if (mime.contains('doc') || mime.contains('word')) return MugliaTheme.info;
    if (mime.contains('image')) return MugliaTheme.success;
    return MugliaTheme.textMuted;
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'modelo':
        return 'Modelo';
      case 'gerado':
        return 'Gerado';
      case 'upload':
        return 'Upload';
      default:
        return tipo;
    }
  }

  Color _corTipo(String tipo) {
    switch (tipo) {
      case 'modelo':
        return MugliaTheme.primary;
      case 'gerado':
        return MugliaTheme.accent;
      case 'upload':
        return MugliaTheme.warning;
      default:
        return MugliaTheme.textMuted;
    }
  }

  String _labelCategoria(String cat) {
    switch (cat) {
      case 'peticao':
        return 'Peticao';
      case 'contestacao':
        return 'Contestacao';
      case 'recurso':
        return 'Recurso';
      case 'agravo':
        return 'Agravo';
      case 'outros':
        return 'Outros';
      default:
        return cat;
    }
  }

  String _formatarData(String data) {
    final partes = data.split('-');
    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }
    return data;
  }

  Future<void> _fazerUpload() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );

    if (resultado != null && resultado.files.isNotEmpty) {
      final arquivo = resultado.files.first;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arquivo selecionado: ${arquivo.name}'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Widget _buildFiltros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Filtros por tipo
          _buildChipFiltro('Todos', 'todos', _filtroTipo, (val) {
            setState(() => _filtroTipo = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Modelos', 'modelo', _filtroTipo, (val) {
            setState(() => _filtroTipo = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Gerados', 'gerado', _filtroTipo, (val) {
            setState(() => _filtroTipo = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Uploads', 'upload', _filtroTipo, (val) {
            setState(() => _filtroTipo = val);
          }),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 24,
            color: MugliaTheme.border,
          ),
          const SizedBox(width: 16),
          // Filtros por categoria
          _buildChipFiltro('Todas', 'todos', _filtroCategoria, (val) {
            setState(() => _filtroCategoria = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Peticao', 'peticao', _filtroCategoria, (val) {
            setState(() => _filtroCategoria = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Contestacao', 'contestacao', _filtroCategoria,
              (val) {
            setState(() => _filtroCategoria = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Recurso', 'recurso', _filtroCategoria, (val) {
            setState(() => _filtroCategoria = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Agravo', 'agravo', _filtroCategoria, (val) {
            setState(() => _filtroCategoria = val);
          }),
          const SizedBox(width: 8),
          _buildChipFiltro('Outros', 'outros', _filtroCategoria, (val) {
            setState(() => _filtroCategoria = val);
          }),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(
    String label,
    String valor,
    String valorAtual,
    ValueChanged<String> onSelected,
  ) {
    final selecionado = valorAtual == valor;
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (_) => onSelected(valor),
      selectedColor: MugliaTheme.primaryDark,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
        color: selecionado ? Colors.white : MugliaTheme.textSecondary,
      ),
    );
  }

  Widget _buildCardDocumento(Map<String, String> doc) {
    final mime = doc['mime'] ?? '';
    final icone = _iconeParaMime(mime);
    final corIcone = _corParaMime(mime);
    final tipo = doc['tipo'] ?? '';
    final categoria = doc['categoria'] ?? '';
    final nome = doc['nome'] ?? '';
    final data = doc['data'] ?? '';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Abrir: $nome')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Area de preview com icone grande
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: corIcone.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    // Icone centralizado
                    Center(
                      child: Icon(
                        icone,
                        size: 48,
                        color: corIcone.withValues(alpha: 0.7),
                      ),
                    ),
                    // Badge de tipo no canto superior direito
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _corTipo(tipo).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _corTipo(tipo).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _labelTipo(tipo),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _corTipo(tipo),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Informacoes do documento
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MugliaTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MugliaTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _labelCategoria(categoria),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: MugliaTheme.textMuted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatarData(data),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: MugliaTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVazio() {
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
                Icons.folder_open_rounded,
                size: 48,
                color: MugliaTheme.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum documento encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajuste os filtros ou faca upload de um novo documento',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docsFiltrados;
    final largura = MediaQuery.of(context).size.width;
    // Responsivo: 2 colunas mobile, 3+ desktop
    final colunas = largura < 600 ? 2 : (largura < 900 ? 3 : 4);

    return MugliaScaffold(
      title: 'Documentos',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Busca de documentos em breve')),
            );
          },
          tooltip: 'Buscar documentos',
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _fazerUpload,
        tooltip: 'Upload de arquivo',
        child: const Icon(Icons.upload_file_rounded),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Filtros
          _buildFiltros(),
          const SizedBox(height: 8),
          // Contador de resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${docs.length} documento${docs.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Grid de documentos
          Expanded(
            child: docs.isEmpty
                ? _buildEstadoVazio()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colunas,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) =>
                        _buildCardDocumento(docs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
