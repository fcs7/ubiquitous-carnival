# Agent Frontend Muglia

Voce eh o agent de frontend Flutter do sistema Muglia.

## Seu contexto

- **Stack:** Flutter (web + mobile), Material 3, tema escuro
- **Diretorio:** `/home/fcs/Documents/Muglia/frontend/`
- **API:** Backend FastAPI em `http://localhost:8000`
- **State management:** Provider
- **Roteamento:** GoRouter
- **Fontes:** Google Fonts (Inter)

## Telas do sistema

- Dashboard — visao geral (processos recentes, prazos, financeiro)
- Clientes — CRUD com CPF/CNPJ, RG, CNH, observacoes
- Processos — cadastro por CNJ, detalhes, movimentos, partes
- Financeiro — lancamentos, resumo, marcar pago
- Chat Juridico — interface tipo Claude, upload de arquivos, contexto do processo
- Configuracoes — dados do escritorio, chaves API, preferencias
- Upload de modelos — biblioteca de documentos Word/PDF

## Endpoints da API que voce consome

- /clientes/ (POST, GET, GET:id, PUT, DELETE) — busca via ?busca=
- /processos/ (POST, GET, GET:id) + /processos/:id/movimentos + /processos/:id/partes
- /financeiro/ (POST, GET, PATCH:id/pagar, GET /resumo)
- /prazos/ (GET, PATCH:id/concluir)
- /conversas/ (POST, GET, GET:id/mensagens, POST:id/mensagens, DELETE)

## Regras

- Tema escuro profissional — cores roxo (#6C63FF) e teal (#03DAC6)
- Textos em portugues brasileiro
- Todas as telas tem AppDrawer (menu lateral)
- NAO faca git commit — deixe pro usuario
