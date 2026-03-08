import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // ── Clientes ──────────────────────────────
  Future<List<dynamic>> getClientes({String? busca}) async {
    final query = busca != null ? '?busca=$busca' : '';
    final resp = await _client.get(Uri.parse('$baseUrl/clientes/$query'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getCliente(int id) async {
    final resp = await _client.get(Uri.parse('$baseUrl/clientes/$id'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> criarCliente(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/clientes/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> atualizarCliente(int id, Map<String, dynamic> data) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/clientes/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<void> deletarCliente(int id) async {
    await _client.delete(Uri.parse('$baseUrl/clientes/$id'));
  }

  // ── Processos ─────────────────────────────
  Future<List<dynamic>> getProcessos() async {
    final resp = await _client.get(Uri.parse('$baseUrl/processos/'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getProcesso(int id) async {
    final resp = await _client.get(Uri.parse('$baseUrl/processos/$id'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> cadastrarProcesso(String cnj) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/processos/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cnj': cnj}),
    );
    return _handleMap(resp);
  }

  Future<List<dynamic>> getMovimentos(int processoId) async {
    final resp = await _client.get(Uri.parse('$baseUrl/processos/$processoId/movimentos'));
    return _handleList(resp);
  }

  Future<List<dynamic>> getPartes(int processoId) async {
    final resp = await _client.get(Uri.parse('$baseUrl/processos/$processoId/partes'));
    return _handleList(resp);
  }

  // ── Financeiro ────────────────────────────
  Future<List<dynamic>> getFinanceiro() async {
    final resp = await _client.get(Uri.parse('$baseUrl/financeiro/'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> criarFinanceiro(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/financeiro/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> marcarPago(int id) async {
    final resp = await _client.patch(Uri.parse('$baseUrl/financeiro/$id/pagar'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> getResumoFinanceiro() async {
    final resp = await _client.get(Uri.parse('$baseUrl/financeiro/resumo'));
    return _handleMap(resp);
  }

  // ── Prazos ────────────────────────────────
  Future<List<dynamic>> getPrazos() async {
    final resp = await _client.get(Uri.parse('$baseUrl/prazos/'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> concluirPrazo(int id) async {
    final resp = await _client.patch(Uri.parse('$baseUrl/prazos/$id/concluir'));
    return _handleMap(resp);
  }

  // ── Chat / Conversas ─────────────────────
  Future<List<dynamic>> getConversas() async {
    final resp = await _client.get(Uri.parse('$baseUrl/conversas/'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> criarConversa(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/conversas/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> getConversaMensagens(int id) async {
    final resp = await _client.get(Uri.parse('$baseUrl/conversas/$id'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> enviarMensagem(int conversaId, String mensagem, {String? modelo}) async {
    final body = {'mensagem': mensagem};
    if (modelo != null) body['modelo'] = modelo;
    final resp = await _client.post(
      Uri.parse('$baseUrl/conversas/$conversaId/mensagens'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handleMap(resp);
  }

  Future<void> deletarConversa(int id) async {
    await _client.delete(Uri.parse('$baseUrl/conversas/$id'));
  }

  // ── Assistente ──────────────────────────────
  Future<Map<String, dynamic>> getAssistenteHistorico({int usuarioId = 1}) async {
    final resp = await _client.get(Uri.parse('$baseUrl/assistente/historico?usuario_id=$usuarioId'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> enviarMensagemAssistente(String mensagem, {int usuarioId = 1}) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/assistente/mensagens?usuario_id=$usuarioId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mensagem': mensagem}),
    );
    return _handleMap(resp);
  }

  // ── Agentes ─────────────────────────────────
  Future<List<dynamic>> getAgentes({int? usuarioId}) async {
    final query = usuarioId != null ? '?usuario_id=$usuarioId' : '';
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/$query'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getAgente(int id) async {
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/$id'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> criarAgente(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/agentes/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> atualizarAgente(int id, Map<String, dynamic> data) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/agentes/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<void> deletarAgente(int id) async {
    await _client.delete(Uri.parse('$baseUrl/agentes/$id'));
  }

  Future<List<dynamic>> getFerramentasDisponiveis() async {
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/ferramentas/disponiveis'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> gerarInstrucao(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/agentes/gerar-instrucao'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> gerarContexto(List<int> clienteIds) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/agentes/gerar-contexto'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cliente_ids': clienteIds}),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> gerarMemoriaDrive(int agenteId, String pastaDriveId) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/agentes/$agenteId/gerar-memoria'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pasta_drive_id': pastaDriveId}),
    );
    return _handleMap(resp);
  }

  Future<List<dynamic>> listarMemoriaAgente(int agenteId) async {
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/$agenteId/memoria'));
    return _handleList(resp);
  }

  // ── Documentos / Google Drive ────────────
  Future<List<dynamic>> listarPastaDrive(String pastaId, {bool apenasPastas = false}) async {
    final query = apenasPastas ? '?apenas_pastas=true' : '';
    final resp = await _client.get(Uri.parse('$baseUrl/documentos/drive/pasta/$pastaId$query'));
    return _handleList(resp);
  }

  Future<List<dynamic>> buscarDrive(String q, {String? pastaId}) async {
    final extra = pastaId != null ? '&pasta_id=$pastaId' : '';
    final resp = await _client.get(Uri.parse('$baseUrl/documentos/drive/buscar?q=$q$extra'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> vincularDocumentoDrive(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/documentos/drive/vincular'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<List<dynamic>> getDocumentosProcesso(int processoId) async {
    final resp = await _client.get(Uri.parse('$baseUrl/documentos/processo/$processoId'));
    return _handleList(resp);
  }

  Future<void> desvincularDocumento(int documentoId) async {
    await _client.delete(Uri.parse('$baseUrl/documentos/$documentoId'));
  }

  Future<Map<String, dynamic>> organizarPastaProcesso(int processoId, {bool simular = false}) async {
    final query = simular ? '?simular=true' : '';
    final resp = await _client.post(Uri.parse('$baseUrl/documentos/drive/organizar/$processoId$query'));
    return _handleMap(resp);
  }

  // ── Status do Sistema ────────────────────
  Future<Map<String, dynamic>> getStatusSistema() async {
    final resp = await _client.get(Uri.parse('$baseUrl/api/status'));
    return _handleMap(resp);
  }

  // ── Health ────────────────────────────────
  Future<bool> healthCheck() async {
    try {
      final resp = await _client.get(Uri.parse('$baseUrl/health'));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────
  List<dynamic> _handleList(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw ApiException(resp.statusCode, resp.body);
  }

  Map<String, dynamic> _handleMap(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw ApiException(resp.statusCode, resp.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
