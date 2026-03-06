import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:muglia/theme/muglia_theme.dart';
import 'package:muglia/widgets/muglia_scaffold.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  // ── Dados do Escritorio ──────────────────
  final _nomeController =
      TextEditingController(text: 'Escritorio Muglia Advocacia');
  final _cnpjController =
      TextEditingController(text: '12.345.678/0001-90');
  final _oabController = TextEditingController(text: 'OAB/SP 123.456');
  final _enderecoController = TextEditingController(
      text: 'Rua das Flores, 123 - Centro, Sao Paulo/SP');
  final _telefoneController =
      TextEditingController(text: '(11) 3456-7890');
  final _emailController =
      TextEditingController(text: 'contato@muglia.adv.br');

  // ── APIs ─────────────────────────────────
  final _openaiKeyController =
      TextEditingController(text: 'sk-proj-abc123...');
  final _anthropicKeyController =
      TextEditingController(text: 'sk-ant-api03-xyz...');
  final _datajudKeyController = TextEditingController(
      text: 'cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw==');
  final _evolutionKeyController =
      TextEditingController(text: 'evo-api-key-123...');

  // Visibilidade dos campos de API
  bool _mostrarOpenai = false;
  bool _mostrarAnthropic = false;
  bool _mostrarDatajud = false;
  bool _mostrarEvolution = false;

  // ── Preferencias ─────────────────────────
  String _modeloClaude = 'claude-sonnet-4-20250514';
  final _horarioController = TextEditingController(text: '07:00');
  bool _notificacoesWhatsApp = true;

  final List<Map<String, String>> _modelosClaude = [
    {'valor': 'claude-haiku-4-20250514', 'label': 'Claude Haiku (rapido)'},
    {'valor': 'claude-sonnet-4-20250514', 'label': 'Claude Sonnet (equilibrado)'},
    {'valor': 'claude-opus-4-20250514', 'label': 'Claude Opus (avancado)'},
  ];

  @override
  void dispose() {
    _nomeController.dispose();
    _cnpjController.dispose();
    _oabController.dispose();
    _enderecoController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _openaiKeyController.dispose();
    _anthropicKeyController.dispose();
    _datajudKeyController.dispose();
    _evolutionKeyController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  void _salvar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuracoes salvas com sucesso'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSecaoTitulo(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MugliaTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icone,
              size: 20,
              color: MugliaTheme.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            titulo,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MugliaTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoTexto({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefixText,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: MugliaTheme.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildCampoApiKey({
    required String label,
    required TextEditingController controller,
    required bool visivel,
    required ValueChanged<bool> onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: !visivel,
        style: visivel
            ? GoogleFonts.inter(fontSize: 14, color: MugliaTheme.textPrimary)
            : GoogleFonts.jetBrainsMono(fontSize: 14, color: MugliaTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: Icon(
              visivel
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: MugliaTheme.textMuted,
              size: 20,
            ),
            onPressed: () => onToggle(!visivel),
            tooltip: visivel ? 'Ocultar' : 'Mostrar',
          ),
        ),
      ),
    );
  }

  Widget _buildSecaoDadosEscritorio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSecaoTitulo('Dados do Escritorio', Icons.business_rounded),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCampoTexto(
                  label: 'Nome do escritorio',
                  controller: _nomeController,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildCampoTexto(
                        label: 'CNPJ',
                        controller: _cnpjController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCampoTexto(
                        label: 'OAB',
                        controller: _oabController,
                      ),
                    ),
                  ],
                ),
                _buildCampoTexto(
                  label: 'Endereco',
                  controller: _enderecoController,
                  maxLines: 2,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildCampoTexto(
                        label: 'Telefone',
                        controller: _telefoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCampoTexto(
                        label: 'E-mail',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoApis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSecaoTitulo('Chaves de API', Icons.key_rounded),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCampoApiKey(
                  label: 'OpenAI API Key',
                  controller: _openaiKeyController,
                  visivel: _mostrarOpenai,
                  onToggle: (val) => setState(() => _mostrarOpenai = val),
                ),
                _buildCampoApiKey(
                  label: 'Anthropic API Key',
                  controller: _anthropicKeyController,
                  visivel: _mostrarAnthropic,
                  onToggle: (val) => setState(() => _mostrarAnthropic = val),
                ),
                _buildCampoApiKey(
                  label: 'DataJud API Key',
                  controller: _datajudKeyController,
                  visivel: _mostrarDatajud,
                  onToggle: (val) => setState(() => _mostrarDatajud = val),
                ),
                _buildCampoApiKey(
                  label: 'Evolution API Key (WhatsApp)',
                  controller: _evolutionKeyController,
                  visivel: _mostrarEvolution,
                  onToggle: (val) => setState(() => _mostrarEvolution = val),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoPreferencias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSecaoTitulo('Preferencias', Icons.tune_rounded),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown modelo Claude
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    value: _modeloClaude,
                    decoration: const InputDecoration(
                      labelText: 'Modelo Claude padrao',
                    ),
                    dropdownColor: MugliaTheme.surfaceVariant,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MugliaTheme.textPrimary,
                    ),
                    items: _modelosClaude
                        .map((m) => DropdownMenuItem<String>(
                              value: m['valor'],
                              child: Text(m['label']!),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _modeloClaude = val);
                      }
                    },
                  ),
                ),
                // Horario de monitoramento
                _buildCampoTexto(
                  label: 'Horario de monitoramento diario',
                  controller: _horarioController,
                  keyboardType: TextInputType.datetime,
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.schedule_rounded,
                      color: MugliaTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: () async {
                      final hora = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 7, minute: 0),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme:
                                  Theme.of(context).colorScheme.copyWith(
                                        surface: MugliaTheme.surface,
                                      ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (hora != null) {
                        _horarioController.text =
                            '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
                      }
                    },
                    tooltip: 'Selecionar horario',
                  ),
                ),
                // Switch WhatsApp
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notificacoes WhatsApp',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: MugliaTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enviar atualizacoes de processos via WhatsApp',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: MugliaTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _notificacoesWhatsApp,
                        onChanged: (val) {
                          setState(() => _notificacoesWhatsApp = val);
                        },
                        activeColor: MugliaTheme.accent,
                        activeTrackColor:
                            MugliaTheme.accent.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MugliaScaffold(
      title: 'Configuracoes',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecaoDadosEscritorio(),
            _buildSecaoApis(),
            _buildSecaoPreferencias(),
            const SizedBox(height: 32),
            // Botao Salvar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _salvar,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  'Salvar configuracoes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
