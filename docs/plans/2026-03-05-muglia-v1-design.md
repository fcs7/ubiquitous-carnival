# Muglia v1 - Design

## Objetivo
Sistema interno do escritorio Muglia para monitorar ~1000 processos judiciais, detectar mudancas via DataJud, traduzir com IA e notificar clientes no WhatsApp.

## Usuarios
2-3 socios. Sem controle de permissoes por enquanto.

## Arquitetura

```
[Celery + Redis]  ->  DataJud API (polling diario 7h)
       |
   [FastAPI]  ->  PostgreSQL (processos, movimentos, clientes)
       |
   [OpenAI]  ->  Resume andamento novo
       |
[Evolution API]  ->  WhatsApp pro cliente
```

## Funcionalidades

1. **Cadastro:** Advogado cadastra CNJ. Sistema identifica tribunal automaticamente pelo codigo J.TT, puxa dados iniciais do DataJud, salva no banco.
2. **Monitoramento:** Todo dia 7h, Celery consulta os ~1000 processos. Compara movimentos com o que ja tem. Achou novo? Marca como pendente.
3. **Traducao IA:** Movimento novo passa pelo OpenAI gpt-4o-mini — transforma juridiques em linguagem simples.
4. **Notificacao:** WhatsApp pro cliente com o resumo traduzido via Evolution API.
5. **Financeiro:** Tabela simples — processo, cliente, valor honorario, custas, status (pago/pendente), gera link PIX via MercadoPago.
6. **Prazos:** Extrai prazos dos movimentos (intimacao, audiencia), mostra lista de prazos proximos.

## Interface

Web simples (React basico ou HTML com FastAPI templates). Telas:
- **Lista de processos** — tabela com filtro por status, cliente, tribunal
- **Detalhe do processo** — movimentos, cliente vinculado, financeiro
- **Prazos** — lista ordenada por data, com alerta de vencimento
- **Clientes** — nome, telefone WhatsApp, processos vinculados
- **Financeiro** — pendencias, valores por cliente

## Banco de dados (PostgreSQL)

- `clientes` (id, nome, telefone, email)
- `processos` (id, cnj, tribunal, classe, cliente_id, status, data_ajuizamento)
- `movimentos` (id, processo_id, codigo, nome, data_hora, notificado, resumo_ia)
- `financeiro` (id, processo_id, tipo, valor, status, data_vencimento)
- `prazos` (id, processo_id, tipo, data_limite, descricao, status)

## Stack

| Camada | Tecnologia |
|---|---|
| Backend | FastAPI + Python |
| Banco | PostgreSQL |
| Fila | Celery + Redis |
| IA | OpenAI gpt-4o-mini |
| WhatsApp | Evolution API (self-hosted) |
| Pagamentos | MercadoPago (PIX) |
| Deploy | Docker Compose no Proxmox |

## Custo mensal: ~R$5 (so OpenAI)

## Fontes de dados

- **DataJud CNJ** (API publica, gratuita)
  - API Key publica: `cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw==`
  - Base URL: `https://api-publica.datajud.cnj.jus.br`
  - Endpoint: `POST /api_publica_{tribunal}/_search`
  - Body: `{"query": {"match": {"numeroProcesso": "CNJ_SEM_FORMATACAO"}}}`
  - Mapeamento completo de 90+ tribunais implementado em `consulta_datajud.py`

## Decisoes tomadas

- Uso interno (nao SaaS)
- DataJud como fonte principal (polling diario)
- Interface simples (nao precisa ser bonita)
- Sem controle de permissoes na v1
- Captura de publicacoes DJe fica para v2
