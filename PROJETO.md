# Muglia - Sistema Juridico Inteligente

## O que eh isso?

Sistema proprio do escritorio Muglia pra acompanhar processos judiciais de forma automatizada. Substitui ferramentas pagas como Astrea (R$89-299/mes) por algo nosso, gratuito, rodando no Proxmox.

**Em uma frase:** O advogado cadastra o CNJ, o sistema monitora 24/7, e o cliente recebe no WhatsApp "Seu processo teve uma atualizacao: [resumo em portugues simples]".

---

## Problema

- Scraping direto nos tribunais NAO funciona (login obrigatorio, captcha, bloqueio)
- Ferramentas pagas sao caras e genericas
- Cliente liga perguntando "e ai doutor, meu processo andou?" — tempo perdido
- Controle financeiro (honorarios, custas) eh manual

## Solucao

APIs oficiais gratuitas (DataJud CNJ) + IA pra traduzir juridiques + WhatsApp automatico.

---

## O que ja existe (hoje)

- `teste_cnj.py` — tentativa de scraping que nao funcionou (caiu na tela de login do TJSP)
- `pagina_processo.html` — HTML salvo da pagina de login (inutil)
- **Conclusao:** scraping eh beco sem saida. APIs eh o caminho.

---

## O que vai ser (visao)

### Fluxo do dia a dia

```
1. Advogado cadastra processo (CNJ) no sistema
2. Todo dia 7h, sistema consulta DataJud automaticamente
3. Achou andamento novo? → OpenAI resume em linguagem simples
4. WhatsApp manda pro cliente: "Atualizacao no seu processo: [resumo]"
5. Dashboard mostra tudo em Kanban (Pendente / Em Andamento / Concluido)
6. Financeiro: gera PIX de honorarios e envia junto
```

### Telas principais

- **Dashboard Kanban** — arrastar cards entre colunas de status
- **Processos** — cadastrar CNJ, ver historico de andamentos
- **Clientes** — dados + telefone WhatsApp + Telegram
- **Financeiro** — boletos PIX pendentes por cliente

---

## Stack tecnica

| Camada | Tecnologia | Por que |
|--------|-----------|---------|
| Backend | FastAPI (Python) | Rapido, async, facil |
| Banco | PostgreSQL | Robusto, gratuito |
| Fila | Celery + Redis | Tarefas agendadas (polling diario) |
| Frontend | React + Tremor UI | Kanban bonito, graficos prontos |
| IA | OpenAI gpt-4o-mini | Barato (~R$0.01/resumo) |
| WhatsApp | Evolution API (self-hosted) | Gratuito, sem burocracia Meta |
| Pagamentos | MercadoPago | PIX nativo |
| Deploy | Docker Compose + Proxmox | Tudo nosso, sem cloud |

---

## Fontes de dados

### DataJud CNJ (principal, GRATUITA)
- API publica do Conselho Nacional de Justica
- Cobre TODOS os tribunais do Brasil
- Precisa: cadastro + API Key (gratis)
- Limitacao: so consulta (pull), sem notificacao push

### Codilo (opcional, pago)
- Tem webhook (push) — avisa instantaneamente quando algo muda
- Trial disponivel em codilo.com.br
- Upgrade futuro se precisar de tempo real

---

## Custos

| Item | Custo |
|------|-------|
| DataJud API | R$0 |
| Evolution API (WhatsApp) | R$0 (self-hosted) |
| OpenAI gpt-4o-mini | ~R$5/mes (500 resumos) |
| PostgreSQL/Redis | R$0 (Docker) |
| Servidor | R$0 (Proxmox proprio) |
| **Total** | **~R$5/mes** |

vs Astrea: R$89-299/mes

---

## Concorrentes

| Ferramenta | Preco/mes | Muglia faz? |
|-----------|-----------|-------------|
| Astrea | R$89-299 | Sim, gratis |
| Juridico AI | R$149+ | Sim, com OpenAI |
| Escavador | R$49-199 | Sim (DataJud) |
| ADVBOX | R$199-499 | Parcial (foco monitoramento) |

**Diferencial:** ninguem junta monitoramento + IA + WhatsApp + PIX + self-hosted + gratis.

---

## CNJ de teste

`0702906-79.2026.8.07.0020` (TJDFT — codigo 8.07)

---

## Decisoes pendentes

- [ ] Uso interno vs produto SaaS?
- [ ] Ja temos API Key DataJud?
- [ ] Comecar pelo backend (API) ou frontend (visual)?
- [ ] Quais processos reais usar como teste alem do CNJ acima?
- [ ] Precisa de Telegram ou so WhatsApp?

---

## Proximo passo

Cadastrar na DataJud, pegar a API Key gratuita, e testar a consulta do CNJ pra confirmar que os dados vem certos. Depois disso, comecamos a codar.
