import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/financeiro.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  List<Financeiro> _lancamentos = [];
  FinanceiroResumo? _resumo;
  bool _carregando = true;
  String? _erro;
  String _filtroStatus = 'todos';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final resultados = await Future.wait([
        api.getFinanceiro(),
        api.getResumoFinanceiro(),
      ]);

      final listaJson = resultados[0] as List<dynamic>;
      final resumoJson = resultados[1] as Map<String, dynamic>;

      setState(() {
        _lancamentos = listaJson
            .map((j) => Financeiro.fromJson(j as Map<String, dynamic>))
            .toList();
        _resumo = FinanceiroResumo.fromJson(resumoJson);
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar dados financeiros: $e';
        _carregando = false;
      });
    }
  }

  List<Financeiro> get _lancamentosFiltrados {
    if (_filtroStatus == 'todos') return _lancamentos;
    return _lancamentos.where((l) => l.status == _filtroStatus).toList();
  }

  Future<void> _marcarComoPago(Financeiro lancamento) async {
    try {
      final api = context.read<ApiService>();
      await api.marcarPago(lancamento.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lancamento marcado como pago')),
        );
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar como pago: $e')),
        );
      }
    }
  }

  void _abrirDialogNovo() {
    showDialog(
      context: context,
      builder: (ctx) => _NovoLancamentoDialog(
        currencyFormat: _currencyFormat,
        onSalvar: (data) async {
          final api = context.read<ApiService>();
          await api.criarFinanceiro(data);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lancamento criado com sucesso')),
            );
            _carregarDados();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Financeiro',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirDialogNovo,
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
          onPressed: _carregarDados,
        ),
      ],
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? _buildErro()
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildResumo()),
                      SliverToBoxAdapter(child: _buildFiltros()),
                      _lancamentosFiltrados.isEmpty
                          ? SliverFillRemaining(child: _buildVazio())
                          : _buildListaLancamentos(),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: MugliaTheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _carregarDados,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumo() {
    if (_resumo == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _ResumoCard(
              titulo: 'Pendente',
              valor: _currencyFormat.format(_resumo!.pendente),
              cor: MugliaTheme.warning,
              icone: Icons.schedule,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ResumoCard(
              titulo: 'Pago',
              valor: _currencyFormat.format(_resumo!.pago),
              cor: MugliaTheme.success,
              icone: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ResumoCard(
              titulo: 'Total',
              valor: _currencyFormat.format(_resumo!.total),
              cor: MugliaTheme.primary,
              icone: Icons.account_balance_wallet_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Filtrar:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          _FiltroChip(
            label: 'Todos',
            selecionado: _filtroStatus == 'todos',
            onTap: () => setState(() => _filtroStatus = 'todos'),
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Pendente',
            selecionado: _filtroStatus == 'pendente',
            cor: MugliaTheme.warning,
            onTap: () => setState(() => _filtroStatus = 'pendente'),
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Pago',
            selecionado: _filtroStatus == 'pago',
            cor: MugliaTheme.success,
            onTap: () => setState(() => _filtroStatus = 'pago'),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: MugliaTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroStatus == 'todos'
                ? 'Nenhum lancamento registrado'
                : 'Nenhum lancamento ${_filtroStatus == 'pendente' ? 'pendente' : 'pago'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: MugliaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no botao + para adicionar',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  SliverList _buildListaLancamentos() {
    final lista = _lancamentosFiltrados;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final lancamento = lista[index];
          return _LancamentoCard(
            lancamento: lancamento,
            currencyFormat: _currencyFormat,
            dateFormat: _dateFormat,
            onMarcarPago: lancamento.status == 'pendente'
                ? () => _marcarComoPago(lancamento)
                : null,
          );
        },
        childCount: lista.length,
      ),
    );
  }
}

// ── Card de resumo ────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData icone;

  const _ResumoCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MugliaTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MugliaTheme.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cor.withValues(alpha: 0.08),
            MugliaTheme.card,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: cor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MugliaTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selecionado;
  final Color? cor;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selecionado,
    this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final corEfetiva = cor ?? MugliaTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? corEfetiva.withValues(alpha: 0.2)
              : MugliaTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selecionado ? corEfetiva : MugliaTheme.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
            color: selecionado ? corEfetiva : MugliaTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Card de lancamento ────────────────────────────────────────────

class _LancamentoCard extends StatelessWidget {
  final Financeiro lancamento;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final VoidCallback? onMarcarPago;

  const _LancamentoCard({
    required this.lancamento,
    required this.currencyFormat,
    required this.dateFormat,
    this.onMarcarPago,
  });

  Color get _corStatus =>
      lancamento.status == 'pago' ? MugliaTheme.success : MugliaTheme.warning;

  String get _labelTipo {
    switch (lancamento.tipo) {
      case 'honorario':
        return 'Honorario';
      case 'custas':
        return 'Custas';
      case 'pericia':
        return 'Pericia';
      case 'acordo':
        return 'Acordo';
      default:
        return lancamento.tipo;
    }
  }

  IconData get _iconeTipo {
    switch (lancamento.tipo) {
      case 'honorario':
        return Icons.gavel;
      case 'custas':
        return Icons.receipt_outlined;
      case 'pericia':
        return Icons.science_outlined;
      case 'acordo':
        return Icons.handshake_outlined;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPago = lancamento.status == 'pago';

    Widget card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: MugliaTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MugliaTheme.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Borda esquerda colorida
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _corStatus,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Conteudo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Linha: tipo chip + status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                MugliaTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconeTipo,
                                  size: 14, color: MugliaTheme.primaryLight),
                              const SizedBox(width: 4),
                              Text(
                                _labelTipo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: MugliaTheme.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _corStatus.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPago ? 'Pago' : 'Pendente',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _corStatus,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Descricao
                    if (lancamento.descricao != null &&
                        lancamento.descricao!.isNotEmpty)
                      Text(
                        lancamento.descricao!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Valor grande
                    Text(
                      currencyFormat.format(lancamento.valor),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isPago
                            ? MugliaTheme.success
                            : MugliaTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Vencimento + processo
                    Row(
                      children: [
                        if (lancamento.dataVencimento != null) ...[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: MugliaTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatarData(lancamento.dataVencimento!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: MugliaTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Processo #${lancamento.processoId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Botao marcar pago
            if (onMarcarPago != null)
              InkWell(
                onTap: onMarcarPago,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: MugliaTheme.success.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: MugliaTheme.success,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Swipe para marcar como pago (apenas pendentes)
    if (onMarcarPago != null) {
      card = Dismissible(
        key: ValueKey(lancamento.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onMarcarPago!();
          return false;
        },
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: MugliaTheme.success.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Marcar pago',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MugliaTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: MugliaTheme.success),
            ],
          ),
        ),
        child: card,
      );
    }

    return card;
  }

  String _formatarData(String dataStr) {
    try {
      final data = DateTime.parse(dataStr);
      return dateFormat.format(data);
    } catch (_) {
      return dataStr;
    }
  }
}

// ── Dialog novo lancamento ────────────────────────────────────────

class _NovoLancamentoDialog extends StatefulWidget {
  final NumberFormat currencyFormat;
  final Future<void> Function(Map<String, dynamic> data) onSalvar;

  const _NovoLancamentoDialog({
    required this.currencyFormat,
    required this.onSalvar,
  });

  @override
  State<_NovoLancamentoDialog> createState() => _NovoLancamentoDialogState();
}

class _NovoLancamentoDialogState extends State<_NovoLancamentoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _processoIdCtrl = TextEditingController();
  final _clienteIdCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _vencimentoCtrl = TextEditingController();

  String _tipoSelecionado = 'honorario';
  bool _salvando = false;
  DateTime? _dataSelecionada;

  static const _tipos = [
    ('honorario', 'Honorario'),
    ('custas', 'Custas'),
    ('pericia', 'Pericia'),
    ('acordo', 'Acordo'),
  ];

  @override
  void dispose() {
    _processoIdCtrl.dispose();
    _clienteIdCtrl.dispose();
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _vencimentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() {
        _dataSelecionada = data;
        _vencimentoCtrl.text = DateFormat('dd/MM/yyyy').format(data);
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final valorTexto = _valorCtrl.text
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll('R\$', '')
        .trim();

    final data = <String, dynamic>{
      'processo_id': int.parse(_processoIdCtrl.text.trim()),
      'cliente_id': int.parse(_clienteIdCtrl.text.trim()),
      'tipo': _tipoSelecionado,
      'descricao': _descricaoCtrl.text.trim(),
      'valor': double.parse(valorTexto),
      'status': 'pendente',
    };

    if (_dataSelecionada != null) {
      data['data_vencimento'] =
          DateFormat('yyyy-MM-dd').format(_dataSelecionada!);
    }

    try {
      await widget.onSalvar(data);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Novo Lancamento',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  // Processo ID + Cliente ID
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _processoIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ID do Processo',
                            prefixIcon: Icon(Icons.folder_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Obrigatorio';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Numero invalido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _clienteIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ID do Cliente',
                            prefixIcon: Icon(Icons.person_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Obrigatorio';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Numero invalido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tipo dropdown
                  DropdownButtonFormField<String>(
                    value: _tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _tipos
                        .map((t) => DropdownMenuItem(
                              value: t.$1,
                              child: Text(t.$2),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _tipoSelecionado = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Descricao
                  TextFormField(
                    controller: _descricaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descricao',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  // Valor + Vencimento
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _valorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Valor (R\$)',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Obrigatorio';
                            }
                            final limpo = v
                                .replaceAll('.', '')
                                .replaceAll(',', '.')
                                .replaceAll('R\$', '')
                                .trim();
                            if (double.tryParse(limpo) == null) {
                              return 'Valor invalido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _vencimentoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vencimento',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          readOnly: true,
                          onTap: _selecionarData,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Botoes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed:
                            _salvando ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _salvando ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_salvando ? 'Salvando...' : 'Salvar'),
                      ),
                    ],
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
