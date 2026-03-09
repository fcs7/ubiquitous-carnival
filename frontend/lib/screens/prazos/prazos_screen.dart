import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/prazo.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

/// Tipos de filtro para a lista de prazos.
enum _FiltroPrazo { todos, pendentes, concluidos }

class PrazosScreen extends StatefulWidget {
  const PrazosScreen({super.key});

  @override
  State<PrazosScreen> createState() => _PrazosScreenState();
}

class _PrazosScreenState extends State<PrazosScreen>
    with TickerProviderStateMixin {
  List<Prazo> _prazos = [];
  bool _carregando = true;
  String? _erro;
  _FiltroPrazo _filtro = _FiltroPrazo.pendentes;

  /// IDs dos prazos que estao sendo concluidos (para animacao).
  final Set<int> _concluindo = {};

  @override
  void initState() {
    super.initState();
    _carregarPrazos();
  }

  Future<void> _carregarPrazos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final dados = await api.getPrazos();
      setState(() {
        _prazos = dados.map((j) => Prazo.fromJson(j)).toList();
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar prazos: $e';
        _carregando = false;
      });
    }
  }

  Future<void> _concluirPrazo(Prazo prazo) async {
    setState(() => _concluindo.add(prazo.id));

    try {
      final api = context.read<ApiService>();
      await api.concluirPrazo(prazo.id);

      // Aguarda a animacao antes de atualizar a lista.
      await Future.delayed(const Duration(milliseconds: 600));
      await _carregarPrazos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao concluir prazo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _concluindo.remove(prazo.id));
    }
  }

  // ── Helpers de data ─────────────────────────────

  int _diasRestantes(Prazo prazo) {
    final limite = DateTime.parse(prazo.dataLimite);
    return limite.difference(DateTime.now()).inDays;
  }

  String _formatarData(String iso) {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  // ── Agrupamento por semana ──────────────────────

  /// Retorna o label do grupo temporal para um prazo.
  String _grupoSemana(Prazo prazo) {
    final dias = _diasRestantes(prazo);
    if (prazo.status == 'concluido') return 'Concluidos';
    if (dias < 0) return 'Atrasados';
    if (dias <= 7) return 'Esta semana';
    if (dias <= 14) return 'Proxima semana';
    return 'Futuro';
  }

  /// Ordem de exibicao dos grupos.
  int _ordemGrupo(String grupo) {
    switch (grupo) {
      case 'Atrasados':
        return 0;
      case 'Esta semana':
        return 1;
      case 'Proxima semana':
        return 2;
      case 'Futuro':
        return 3;
      case 'Concluidos':
        return 4;
      default:
        return 5;
    }
  }

  // ── Filtragem ───────────────────────────────────

  List<Prazo> get _prazosFiltrados {
    List<Prazo> resultado;
    switch (_filtro) {
      case _FiltroPrazo.pendentes:
        resultado = _prazos.where((p) => p.status != 'concluido').toList();
        break;
      case _FiltroPrazo.concluidos:
        resultado = _prazos.where((p) => p.status == 'concluido').toList();
        break;
      case _FiltroPrazo.todos:
        resultado = List.of(_prazos);
        break;
    }

    // Ordena por data limite (mais urgente primeiro).
    resultado.sort((a, b) {
      final dA = DateTime.parse(a.dataLimite);
      final dB = DateTime.parse(b.dataLimite);
      return dA.compareTo(dB);
    });

    return resultado;
  }

  int get _pendentesCount =>
      _prazos.where((p) => p.status != 'concluido').length;

  // ── Cor e icone por urgencia / tipo ─────────────

  Color _corUrgencia(int dias) {
    if (dias < 0) return MugliaTheme.error;
    if (dias < 3) return MugliaTheme.error;
    if (dias < 7) return MugliaTheme.warning;
    return MugliaTheme.success;
  }

  IconData _iconeTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'intimacao':
        return Icons.gavel;
      case 'audiencia':
        return Icons.people;
      case 'pericia':
        return Icons.science;
      case 'recurso':
        return Icons.description;
      case 'contestacao':
        return Icons.edit_document;
      default:
        return Icons.event;
    }
  }

  Color _corTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'intimacao':
        return MugliaTheme.primary;
      case 'audiencia':
        return MugliaTheme.accent;
      case 'pericia':
        return MugliaTheme.info;
      case 'recurso':
        return MugliaTheme.warning;
      default:
        return MugliaTheme.textMuted;
    }
  }

  // ── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Prazos',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
          onPressed: _carregarPrazos,
        ),
      ],
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? _buildErro()
              : _buildConteudo(),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: MugliaTheme.error),
            const SizedBox(height: 16),
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _carregarPrazos,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    final filtrados = _prazosFiltrados;

    return Column(
      children: [
        // Contador + filtros
        _buildHeader(),

        // Lista
        Expanded(
          child: filtrados.isEmpty
              ? _buildEstadoVazio()
              : RefreshIndicator(
                  onRefresh: _carregarPrazos,
                  color: MugliaTheme.primary,
                  child: _buildListaAgrupada(filtrados),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contador de pendentes
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _pendentesCount > 0
                      ? MugliaTheme.primary.withValues(alpha: 0.15)
                      : MugliaTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _pendentesCount > 0
                          ? Icons.schedule
                          : Icons.check_circle,
                      size: 16,
                      color: _pendentesCount > 0
                          ? MugliaTheme.primary
                          : MugliaTheme.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _pendentesCount > 0
                          ? '$_pendentesCount prazo${_pendentesCount == 1 ? '' : 's'} pendente${_pendentesCount == 1 ? '' : 's'}'
                          : 'Nenhum prazo pendente',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _pendentesCount > 0
                            ? MugliaTheme.primary
                            : MugliaTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Chips de filtro
          Wrap(
            spacing: 8,
            children: [
              _buildFiltroChip('Todos', _FiltroPrazo.todos),
              _buildFiltroChip('Pendentes', _FiltroPrazo.pendentes),
              _buildFiltroChip('Concluidos', _FiltroPrazo.concluidos),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, _FiltroPrazo filtro) {
    final selecionado = _filtro == filtro;
    return FilterChip(
      label: Text(label),
      selected: selecionado,
      onSelected: (_) => setState(() => _filtro = filtro),
      selectedColor: MugliaTheme.primaryDark,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: selecionado ? Colors.white : MugliaTheme.textSecondary,
      ),
    );
  }

  Widget _buildEstadoVazio() {
    String mensagem;
    IconData icone;
    switch (_filtro) {
      case _FiltroPrazo.pendentes:
        mensagem = 'Nenhum prazo pendente.\nTudo em dia!';
        icone = Icons.celebration;
        break;
      case _FiltroPrazo.concluidos:
        mensagem = 'Nenhum prazo concluido ainda.';
        icone = Icons.hourglass_empty;
        break;
      case _FiltroPrazo.todos:
        mensagem = 'Nenhum prazo cadastrado.';
        icone = Icons.event_busy;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 72, color: MugliaTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MugliaTheme.textMuted,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista agrupada por semana ───────────────────

  Widget _buildListaAgrupada(List<Prazo> prazos) {
    // Agrupa por label de semana.
    final Map<String, List<Prazo>> grupos = {};
    for (final p in prazos) {
      final g = _grupoSemana(p);
      grupos.putIfAbsent(g, () => []);
      grupos[g]!.add(p);
    }

    // Ordena os grupos.
    final gruposOrdenados = grupos.entries.toList()
      ..sort((a, b) => _ordemGrupo(a.key).compareTo(_ordemGrupo(b.key)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: gruposOrdenados.length,
      itemBuilder: (context, i) {
        final grupo = gruposOrdenados[i];
        return _buildGrupo(grupo.key, grupo.value);
      },
    );
  }

  Widget _buildGrupo(String titulo, List<Prazo> prazos) {
    // Cor do header do grupo.
    Color corGrupo;
    switch (titulo) {
      case 'Atrasados':
        corGrupo = MugliaTheme.error;
        break;
      case 'Esta semana':
        corGrupo = MugliaTheme.warning;
        break;
      case 'Proxima semana':
        corGrupo = MugliaTheme.info;
        break;
      case 'Concluidos':
        corGrupo = MugliaTheme.success;
        break;
      default:
        corGrupo = MugliaTheme.textMuted;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header do grupo
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: corGrupo,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: corGrupo,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${prazos.length})',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: MugliaTheme.textMuted,
                ),
              ),
            ],
          ),
        ),

        // Cards do grupo
        ...prazos.map((p) => _buildCardPrazo(p)),
      ],
    );
  }

  Widget _buildCardPrazo(Prazo prazo) {
    final dias = _diasRestantes(prazo);
    final concluido = prazo.status == 'concluido';
    final animandoConclusao = _concluindo.contains(prazo.id);

    return AnimatedOpacity(
      opacity: animandoConclusao ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline indicator (barra lateral de urgencia)
                  Container(
                    width: 4,
                    height: 64,
                    decoration: BoxDecoration(
                      color: concluido
                          ? MugliaTheme.success
                          : _corUrgencia(dias),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Conteudo central
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tipo (chip) + dias restantes
                        Row(
                          children: [
                            // Chip do tipo
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _corTipo(prazo.tipo).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _iconeTipo(prazo.tipo),
                                    size: 13,
                                    color: _corTipo(prazo.tipo),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    prazo.tipo[0].toUpperCase() +
                                        prazo.tipo.substring(1),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _corTipo(prazo.tipo),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Badge de dias restantes
                            if (!concluido)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _corUrgencia(dias)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dias < 0
                                      ? '${dias.abs()} dia${dias.abs() == 1 ? '' : 's'} atrasado'
                                      : dias == 0
                                          ? 'Hoje'
                                          : dias == 1
                                              ? 'Amanha'
                                              : '$dias dias',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _corUrgencia(dias),
                                  ),
                                ),
                              ),
                            if (concluido)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: MugliaTheme.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Concluido',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: MugliaTheme.success,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Descricao
                        Text(
                          prazo.descricao ?? 'Sem descricao',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: concluido || animandoConclusao
                                ? MugliaTheme.textMuted
                                : MugliaTheme.textPrimary,
                            decoration: concluido || animandoConclusao
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: MugliaTheme.textMuted,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Data limite + processo
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: MugliaTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatarData(prazo.dataLimite),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: MugliaTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.folder_outlined,
                              size: 13,
                              color: MugliaTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Processo #${prazo.processoId}',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: MugliaTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Checkbox para concluir
                  if (!concluido)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: animandoConclusao
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MugliaTheme.success,
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: MugliaTheme.textMuted,
                                  size: 24,
                                ),
                                tooltip: 'Concluir prazo',
                                onPressed: () => _concluirPrazo(prazo),
                              ),
                      ),
                    ),
                  if (concluido)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle,
                        color: MugliaTheme.success,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
