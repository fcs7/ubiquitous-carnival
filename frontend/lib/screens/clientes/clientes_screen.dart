import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:muglia/models/cliente.dart';
import 'package:muglia/services/api_service.dart';
import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<Cliente> _clientes = [];
  bool _carregando = true;
  String? _erro;
  bool _buscaAberta = false;
  final _buscaController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _carregarClientes();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _carregarClientes({String? busca}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final api = context.read<ApiService>();
      final lista = await api.getClientes(busca: busca);
      setState(() {
        _clientes = lista.map((j) => Cliente.fromJson(j)).toList();
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar clientes';
        _carregando = false;
      });
    }
  }

  void _onBuscaChanged(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _carregarClientes(busca: valor.isEmpty ? null : valor);
    });
  }

  Color _corAvatar(String nome) {
    final cores = [
      MugliaTheme.primary,
      MugliaTheme.accent,
      MugliaTheme.success,
      MugliaTheme.warning,
      MugliaTheme.info,
      MugliaTheme.primaryLight,
      MugliaTheme.accentDark,
      const Color(0xFFE879F9),
      const Color(0xFFFB923C),
      const Color(0xFF34D399),
    ];
    final hash = nome.codeUnits.fold<int>(0, (prev, c) => prev + c);
    return cores[hash % cores.length];
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.length >= 2) {
      return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
    }
    return nome.substring(0, nome.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _chipTipo(String cpfCnpj) {
    final soDigitos = cpfCnpj.replaceAll(RegExp(r'\D'), '');
    final isPJ = soDigitos.length >= 14;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPJ
            ? MugliaTheme.accent.withValues(alpha: 0.15)
            : MugliaTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPJ
              ? MugliaTheme.accent.withValues(alpha: 0.4)
              : MugliaTheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        isPJ ? 'PJ' : 'PF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPJ ? MugliaTheme.accent : MugliaTheme.primaryLight,
          letterSpacing: 0.5,
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
                Icons.people_outline_rounded,
                size: 48,
                color: MugliaTheme.primaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum cliente cadastrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no botao + para adicionar o primeiro cliente',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: MugliaTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _erro ?? 'Erro desconhecido',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MugliaTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _carregarClientes(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCliente(Cliente cliente) {
    final cor = _corAvatar(cliente.nome);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/clientes/${cliente.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: cor.withValues(alpha: 0.2),
                  child: Text(
                    _iniciais(cliente.nome),
                    style: TextStyle(
                      color: cor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Dados
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cliente.nome,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _chipTipo(cliente.cpfCnpj),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cliente.cpfCnpj,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (cliente.telefone.isNotEmpty) ...[
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: MugliaTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cliente.telefone,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (cliente.email != null &&
                              cliente.email!.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: MugliaTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cliente.email!,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MugliaTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Clientes',
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _buscaAberta ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(_buscaAberta),
            ),
          ),
          onPressed: () {
            setState(() {
              _buscaAberta = !_buscaAberta;
              if (!_buscaAberta) {
                _buscaController.clear();
                _carregarClientes();
              }
            });
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/clientes/novo'),
        tooltip: 'Novo cliente',
        child: const Icon(Icons.person_add_rounded),
      ),
      body: Column(
        children: [
          // Barra de busca animada
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _buscaAberta ? 72 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _buscaAberta ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _buscaController,
                  onChanged: _onBuscaChanged,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, CPF/CNPJ, telefone...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: MugliaTheme.textMuted,
                    ),
                    suffixIcon: _buscaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: MugliaTheme.textMuted),
                            onPressed: () {
                              _buscaController.clear();
                              _carregarClientes();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          // Conteudo
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MugliaTheme.primary,
                    ),
                  )
                : _erro != null
                    ? _buildErro()
                    : _clientes.isEmpty
                        ? _buildEstadoVazio()
                        : RefreshIndicator(
                            color: MugliaTheme.primary,
                            backgroundColor: MugliaTheme.surface,
                            onRefresh: () => _carregarClientes(
                              busca: _buscaController.text.isEmpty
                                  ? null
                                  : _buscaController.text,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 88),
                              itemCount: _clientes.length,
                              itemBuilder: (context, index) =>
                                  _buildCardCliente(_clientes[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
