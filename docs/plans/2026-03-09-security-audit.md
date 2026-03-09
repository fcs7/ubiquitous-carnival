# Auditoria de Seguranca — Muglia

**Data:** 2026-03-09
**Escopo:** Backend (FastAPI), Frontend (Flutter), Infraestrutura (Docker/nginx)
**Metodologia:** 4 agentes especializados (OWASP, silent-failure-hunter, code-reviewer, frontend audit)

---

## Resumo Executivo

O sistema tem **zero autenticacao**, API keys reais expostas, webhook bypassavel, e multiplos pontos de falha silenciosa. Para um sistema juridico que lida com CPF, RG, CNH e comunicacoes advogado-cliente, isso e critico.

**Contagem:** 4 CRITICOS, 8 ALTOS, 14 MEDIOS, 7 BAIXOS = 33 achados

---

## CRITICOS (corrigir IMEDIATAMENTE)

### C1: API Keys Reais Expostas
- **Onde:** `backend/.env:3,8` e `frontend/configuracoes_screen.dart:35`
- **O que:** Chaves OpenAI `sk-svcacct-...`, Anthropic `sk-ant-api03-...` no disco. Chave DataJud hardcoded no Dart (compilada no JS bundle)
- **Impacto:** Qualquer pessoa com acesso ao repo/disco tem acesso completo as APIs
- **Fix:** Rotacionar TODAS as chaves. Remover do .env.example. Limpar valores default do configuracoes_screen.dart

### C2: Zero Autenticacao em Todos os Endpoints
- **Onde:** `main.py`, todos os routers
- **O que:** Nenhum JWT, API key, session cookie ou middleware de auth. Portas 8000 e 3000 abertas. Swagger UI publico
- **Impacto:** Qualquer maquina na rede acessa tudo: clientes, processos, chat IA, Drive, dados financeiros
- **Fix:** Implementar auth (minimo: API key header via FastAPI Depends)

### C3: `usuario_id` Spoofavel como Query Param
- **Onde:** `routers/assistente.py:23`, `routers/agentes.py:238,259`
- **O que:** `?usuario_id=2` permite agir como outro usuario
- **Fix:** Derivar usuario_id de token autenticado, nunca do client

### C4: Webhook Vindi Sem Auth Quando Secret Vazio
- **Onde:** `routers/vindi_webhook.py:33`, `config.py:8`
- **O que:** Default do secret e `""` (falsy). Quando nao configurado, QUALQUER POST cria registros no banco
- **Fix:** Rejeitar requests quando secret nao configurado (fail closed)

---

## ALTOS

### H1: Path Traversal em Memoria de Agente
- **Onde:** `services/memoria_agente.py:131-133`
- **O que:** Nomes de arquivo gerados pela IA usados como paths no disco sem validacao. `../../app/main.py` sobrescreve arquivos
- **Fix:** Validar com regex `^[a-z0-9_-]+\.md$` + `caminho.resolve().is_relative_to(pasta.resolve())`

### H2: Modelo IA Arbitrario Aceito do Client
- **Onde:** `schemas.py:157,192`
- **O que:** Qualquer string aceita como modelo. Atacante pode usar `claude-opus-4-5` = custo ilimitado
- **Fix:** Adicionar `Literal["claude-sonnet-4-6", "claude-haiku-4-5-20251001", "gpt-4o-mini"]`

### H3: `/api/status` Expoe Infraestrutura Sem Auth
- **Onde:** `routers/status.py:63`
- **O que:** Revela quais APIs estao ativas, erros do banco (pode vazar hostname)
- **Fix:** Restringir a usuarios autenticados ou reduzir detalhes

### H4: `--reload` no Dockerfile de Producao
- **Onde:** `backend/Dockerfile:9`
- **O que:** Hot-reload + volume mount = injecao de codigo. Tracebacks expostos
- **Fix:** Usar `--workers 2` sem `--reload`. Volume mount so em dev

### H5: Senha PostgreSQL Trivial + Porta Exposta
- **Onde:** `docker-compose.yml:4-8`
- **O que:** Senha `muglia`, porta 5432 em `0.0.0.0`. Banco acessivel de qualquer maquina na rede
- **Fix:** Senha forte via Docker secret. Remover `ports: "5432:5432"`

### H6: Sem HTTPS/TLS
- **Onde:** `nginx.conf:1`
- **O que:** Todo trafego (CPF, processos, chat IA) em texto plano
- **Fix:** Configurar TLS no nginx com certificado

### H7: Container Roda como Root
- **Onde:** `backend/Dockerfile`, `frontend/Dockerfile`
- **O que:** Sem diretiva `USER`. Processo roda como root no container
- **Fix:** Adicionar `RUN useradd -m appuser` + `USER appuser`

### H8: Webhook Handlers Engolem Erros Silenciosamente
- **Onde:** `routers/vindi_webhook.py:42-46`, `services/vindi.py`
- **O que:** Sem try/except nos handlers. Eventos desconhecidos retornam `{"status": "ok"}`. Vindi nao retenta. Dados financeiros divergem
- **Fix:** Adicionar error handling por evento, log erros, retornar 400/500 quando falhar

---

## MEDIOS

### M1: Prompt Injection via Dados do Banco
- **Onde:** `services/claude_chat.py:41-61`, `services/agente_chat.py:20-41`
- **O que:** Nome de cliente, movimentos, config do escritorio interpolados no system prompt sem sanitizacao
- **Fix:** Delimitar dados com XML tags claras, validar ConfigEscritorio no write

### M2: PII (CPF/CNPJ) Enviado para APIs de IA
- **Onde:** `services/claude_chat.py:55`, `services/ferramentas/cliente.py`
- **O que:** CPF (equivalente ao SSN brasileiro) enviado para Anthropic/OpenAI. Possivel violacao LGPD
- **Fix:** Documentar decisao, considerar mascaramento, verificar acordos de processamento de dados

### M3: Leitura do Drive Ignora Validacao de Pasta Raiz
- **Onde:** `routers/documentos.py:27,47`
- **O que:** `listar_pasta` e `metadados_drive` aceitam qualquer folder ID sem checar se esta dentro da raiz
- **Fix:** Adicionar `_validar_dentro_raiz()` nos endpoints de leitura

### M4: JSON Fallback Silencioso em Ferramentas do Agente
- **Onde:** `services/agente_chat.py:145-148`, `services/assistente.py:182-185`, `schemas.py:363-366`
- **O que:** Se `ferramentas_habilitadas` tem JSON invalido, silenciosamente vira `[]`. Agente perde todas as tools
- **Fix:** Logar corrupção e levantar erro

### M5: Tool Execution Catch-All Engole Erros de Seguranca
- **Onde:** `services/agente_chat.py:57-65`
- **O que:** `except Exception` transforma erros de seguranca do Drive em tool result para a IA
- **Fix:** Re-raise `DriveServiceError` com "SEGURANCA"

### M6: Frontend Delete Operations Ignoram Resposta
- **Onde:** `frontend/api_service.dart:41-43,117-119,166-168,234-236`
- **O que:** Deletes nao checam status HTTP. UI mostra sucesso mesmo se falhou. Problema para LGPD (direito a exclusao)
- **Fix:** Checar `resp.statusCode` e throw `ApiException`

### M7: Webhook Sem Limite de Body
- **Onde:** `routers/vindi_webhook.py:31`
- **O que:** `await request.body()` sem limite de tamanho. DoS via payload gigante
- **Fix:** Adicionar check de Content-Length

### M8: `PrazoCreate.status` Aceita String Arbitraria
- **Onde:** `schemas.py:135`
- **O que:** Status pode ser criado como "concluido", bypassando workflow
- **Fix:** Usar `Literal["pendente"]` no create

### M9: Erros Raw do Servidor na UI
- **Onde:** `documentos_screen.dart:64,98`, `routers/agentes.py:152`
- **O que:** `str(e)` retornado em HTTPException. Pode vazar SQL, paths, prompts
- **Fix:** Logar detalhes, retornar mensagem generica

### M10: Rate Limiting Zero
- **Onde:** Todos os routers
- **O que:** Sem throttling. Chat IA = custo por request. Loop infinito esgota budget
- **Fix:** Adicionar `slowapi` ou rate limit no nginx

### M11: Memoria de Agente Deleta Antes de Confirmar Novos Arquivos
- **Onde:** `services/memoria_agente.py:126-134`
- **O que:** Deleta .md antigos, depois tenta escrever novos. Se write falha = tudo perdido
- **Fix:** Escrever em dir temporario, depois swap atomico

### M12: Webhook `bill_paid` Silencioso Quando Bill Nao Existe
- **Onde:** `services/vindi.py:129-139`
- **O que:** Se `bill_created` falhou antes, `bill_paid` e silenciosamente ignorado. Cliente pagou mas sistema nao registra
- **Fix:** Logar como erro critico

### M13: AI Provider Errors Sem Tratamento
- **Onde:** `services/claude_chat.py:109-114`, `routers/chat.py:65-82`
- **O que:** Rate limit, auth error, network timeout = 500 opaco. Pode vazar system prompt no traceback
- **Fix:** Catch especifico por tipo de erro do provider

### M14: Tela de Configuracoes Nao Salva Nada
- **Onde:** `configuracoes_screen.dart:72`
- **O que:** Botao "Salvar" mostra SnackBar mas nao faz API call. Mudancas descartadas silenciosamente

---

## BAIXOS

### L1: Sem Headers de Seguranca no nginx
- **Onde:** `nginx.conf`
- **O que:** Sem X-Frame-Options, CSP, X-Content-Type-Options
- **Fix:** Adicionar headers de seguranca

### L2: Drive Scope Muito Amplo
- **Onde:** `google_drive.py:23`
- **O que:** `auth/drive` (acesso total) em vez de `auth/drive.file` (so arquivos criados pelo app)

### L3: Cache PDF em `/tmp` (World-Readable)
- **Onde:** `pdf_extractor.py:72`
- **O que:** Documentos juridicos em plaintext no `/tmp`, sem expiracao

### L4: `_safe_file_id` Usa Denylist
- **Onde:** `pdf_extractor.py:67`
- **O what:** Substitui `..` e `/` mas nao usa allowlist. Usar `re.sub(r'[^a-zA-Z0-9_-]', '_', file_id)`

### L5: Sem Pool Config no SQLAlchemy
- **Onde:** `database.py:6`
- **O que:** Sem `pool_size`, `pool_pre_ping`. Connection exhaustion sob carga

### L6: Google Fonts de CDN Externo
- **Onde:** `pubspec.yaml:43`
- **O que:** Requests para fonts.gstatic.com vazam atividade para Google

### L7: Drive Credential Cache Nunca Expira
- **Onde:** `google_drive.py:49`
- **O que:** `@functools.cache` nunca expira. Rotacao de credenciais requer restart

---

## Prioridade de Remediacao

### Fase 1: Emergencia (fazer AGORA)
1. Rotacionar API keys (OpenAI + Anthropic + DataJud)
2. Remover chaves hardcoded do configuracoes_screen.dart e .env.example
3. Implementar autenticacao basica (API key header)
4. Tornar vindi_webhook_secret obrigatorio
5. Fix path traversal em gerar_e_salvar_memoria

### Fase 2: Antes de Deploy
6. Remover `--reload` do Dockerfile
7. Senha forte no PostgreSQL + remover porta publica
8. Allowlist de modelos IA
9. Rate limiting
10. HTTPS/TLS
11. USER non-root nos Dockerfiles
12. Error handling nos webhook handlers

### Fase 3: Hardening
13. Validacao de pasta raiz nos endpoints de leitura do Drive
14. Headers de seguranca no nginx
15. Scope restrito do Drive
16. Sanitizacao de dados no system prompt
17. Cache PDF com permissoes restritas
18. Pool config no SQLAlchemy

---

## Observacoes Positivas

O codigo tem boas praticas em varios pontos:
- `_validar_dentro_raiz` no Google Drive (validacao de escopo para operacoes de escrita)
- Zero operacoes de delete no Drive (politica de seguranca)
- Custom exceptions (`DriveServiceError`, `PdfExtractionError`)
- Audit logging para operacoes de escrita no Drive
- Pattern de re-raise em `agente_chat.py` que salva mensagem do usuario mesmo em falha
- Validacao de ferramentas no schema Pydantic (allowlist)
