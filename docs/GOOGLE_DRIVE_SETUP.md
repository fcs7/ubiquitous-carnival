# Configuracao do Google Drive — Google Workspace

Guia passo a passo para configurar a integracao do Muglia com Google Drive usando Service Account no Google Workspace.

## Pre-requisitos

- Conta Google Workspace (ex: `socio@muglia.adv.br`)
- Acesso de administrador ao Google Workspace Admin Console
- Acesso ao Google Cloud Console
- Docker Compose configurado no Muglia

---

## Passo 1: Criar projeto no Google Cloud Console

1. Acesse https://console.cloud.google.com/
2. Clique em **Selecionar projeto** no topo da pagina
3. Clique em **Novo projeto**
4. Preencha:
   - Nome do projeto: `Muglia`
   - Organizacao: selecione o dominio do escritorio (ex: `muglia.adv.br`)
5. Clique em **Criar**
6. Aguarde a criacao e selecione o projeto `Muglia`

---

## Passo 2: Ativar a Google Drive API

1. No menu lateral, va em **APIs e servicos** > **Biblioteca**
2. Busque por `Google Drive API`
3. Clique no resultado **Google Drive API**
4. Clique em **Ativar**
5. Aguarde a ativacao (leva alguns segundos)

---

## Passo 3: Criar Service Account

1. No menu lateral, va em **IAM e administracao** > **Contas de servico**
2. Clique em **Criar conta de servico**
3. Preencha:
   - Nome: `muglia-drive`
   - ID: `muglia-drive` (gerado automaticamente)
   - Descricao: `Acesso ao Google Drive para o sistema Muglia`
4. Clique em **Criar e continuar**
5. Na etapa "Conceder acesso" — pule, clique em **Continuar**
6. Na etapa "Conceder acesso aos usuarios" — pule, clique em **Concluir**

---

## Passo 4: Gerar chave JSON

1. Na lista de contas de servico, clique no email da conta criada (ex: `muglia-drive@muglia-XXXXX.iam.gserviceaccount.com`)
2. Va na aba **Chaves**
3. Clique em **Adicionar chave** > **Criar nova chave**
4. Selecione **JSON**
5. Clique em **Criar**
6. O arquivo JSON sera baixado automaticamente (ex: `muglia-XXXXX-abc123.json`)
7. **IMPORTANTE**: guarde este arquivo em local seguro. Ele da acesso ao Drive.

### Copiar para o projeto

```bash
# Na raiz do projeto Muglia
mkdir -p secrets
cp ~/Downloads/muglia-XXXXX-abc123.json secrets/google_credentials.json
```

O arquivo `secrets/` ja esta no `.gitignore` — nunca sera commitado.

---

## Passo 5: Delegacao de dominio (Google Workspace)

Esta etapa permite que o Service Account acesse o Drive de usuarios do dominio.

**NOTA**: Se voce prefere compartilhar apenas uma pasta especifica com o Service Account (Passo 6B), pode pular esta etapa.

### No Google Workspace Admin Console

1. Acesse https://admin.google.com/
2. Va em **Seguranca** > **Acesso e controle de dados** > **Controles da API**
3. Clique em **Gerenciar delegacao em todo o dominio**
4. Clique em **Adicionar novo**
5. Preencha:
   - **ID do cliente**: copie o campo `client_id` do arquivo JSON (numero longo, ex: `123456789012345678901`)
   - **Escopos OAuth**: `https://www.googleapis.com/auth/drive`
6. Clique em **Autorizar**

### Como encontrar o client_id

Abra o arquivo `secrets/google_credentials.json` e procure o campo `client_id`:

```bash
cat secrets/google_credentials.json | python3 -c "import sys,json; print(json.load(sys.stdin)['client_id'])"
```

---

## Passo 6: Compartilhar pasta do Drive com o Service Account

Voce precisa dar acesso ao Service Account na pasta raiz que o Muglia vai gerenciar.

### Opcao A: Pasta especifica (RECOMENDADO)

1. Abra o Google Drive (https://drive.google.com/)
2. Crie uma pasta raiz para o Muglia (ex: `Muglia Juridico`) ou use uma existente
3. Clique com botao direito na pasta > **Compartilhar**
4. No campo "Adicionar pessoas", cole o **email do Service Account**
   - O email esta no arquivo JSON, campo `client_email`
   - Formato: `muglia-drive@muglia-XXXXX.iam.gserviceaccount.com`
5. Selecione permissao **Editor** (necessario para criar pastas e mover arquivos)
6. Desmarque "Notificar pessoas" (Service Account nao tem email real)
7. Clique em **Compartilhar**

### Como encontrar o email do Service Account

```bash
cat secrets/google_credentials.json | python3 -c "import sys,json; print(json.load(sys.stdin)['client_email'])"
```

### Opcao B: Drive inteiro (menos seguro)

Use a delegacao de dominio (Passo 5) para acessar todo o Drive. Nao recomendado — o principio de menor privilegio sugere compartilhar apenas a pasta necessaria.

---

## Passo 7: Obter o ID da pasta raiz

1. Abra a pasta raiz no Google Drive
2. Olhe a URL no navegador:
   ```
   https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUvWxYz
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                          Este eh o ID da pasta
   ```
3. Copie o ID (string alfanumerica depois de `/folders/`)

---

## Passo 8: Configurar variaveis de ambiente

Edite o arquivo `backend/.env` e adicione:

```env
# Google Drive
GOOGLE_CREDENTIALS_PATH=/run/secrets/google_credentials.json
GOOGLE_DRIVE_ROOT_FOLDER_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz
GOOGLE_DRIVE_PASTA_PROCESSOS=Processos
GOOGLE_DRIVE_PASTA_CLIENTES=Clientes
```

Substitua `1AbCdEfGhIjKlMnOpQrStUvWxYz` pelo ID real da pasta raiz (Passo 7).

### Variaveis disponiveis

| Variavel | Descricao | Exemplo |
|---|---|---|
| `GOOGLE_CREDENTIALS_PATH` | Caminho do JSON dentro do container | `/run/secrets/google_credentials.json` |
| `GOOGLE_DRIVE_ROOT_FOLDER_ID` | ID da pasta raiz no Drive | `1AbCdEfGhIjKlMnOpQrStUvWxYz` |
| `GOOGLE_DRIVE_PASTA_PROCESSOS` | Nome da subpasta de processos | `Processos` |
| `GOOGLE_DRIVE_PASTA_CLIENTES` | Nome da subpasta de clientes | `Clientes` |

---

## Passo 9: Subir o sistema

```bash
# Na raiz do projeto
docker compose up -d --build
```

O `docker-compose.yml` ja monta o arquivo de credenciais como volume read-only:

```yaml
volumes:
  - ./secrets/google_credentials.json:/run/secrets/google_credentials.json:ro
```

---

## Passo 10: Testar a integracao

### Via API (curl)

```bash
# Listar conteudo da pasta raiz
curl http://localhost:8000/documentos/drive/pasta/SEU_FOLDER_ID

# Buscar arquivo por nome
curl "http://localhost:8000/documentos/drive/buscar?q=peticao"

# Simular organizacao de pasta para um processo (dry-run)
curl -X POST "http://localhost:8000/documentos/drive/organizar/1?simular=true"

# Criar pasta de processo no Drive (executa de verdade)
curl -X POST "http://localhost:8000/documentos/drive/organizar/1"
```

### Via Frontend

1. Acesse http://localhost:3000/
2. Va em **Documentos** no menu lateral
3. Na aba **Google Drive**, informe o ID da pasta raiz
4. Navegue pelas pastas e vincule arquivos a processos

---

## Estrutura de pastas criada pelo Muglia

Quando voce clica em "Organizar" para um processo, o sistema cria:

```
Muglia Juridico/              <-- pasta raiz (GOOGLE_DRIVE_ROOT_FOLDER_ID)
  Processos/                  <-- criada automaticamente
    0001234-56.2024.8.26.0001 — Joao Silva/    <-- CNJ + nome do cliente
    0005678-90.2024.8.13.0002 — Maria Santos/
  Clientes/                   <-- criada automaticamente (uso futuro)
```

---

## Seguranca

O sistema implementa 5 camadas de protecao:

1. **Service Account com escopo restrito** — acessa apenas a pasta compartilhada, nao o Drive inteiro
2. **Validacao de escopo** — toda operacao de escrita verifica que o destino esta dentro da pasta raiz. Se nao estiver, retorna erro HTTP 403
3. **Zero delete** — nenhum endpoint ou funcao do sistema apaga arquivos do Drive. O maximo que faz eh desvincular (remove a referencia do banco, o arquivo permanece intacto no Drive)
4. **Audit log** — toda operacao que modifica o Drive (criar pasta, mover arquivo) gera log com detalhes
5. **Modo simulacao** — o endpoint de organizacao aceita `?simular=true` para mostrar o que seria feito sem modificar nada

### Permissoes minimas do Service Account

| Operacao | Permissao necessaria |
|---|---|
| Listar/buscar arquivos | Leitor (Viewer) |
| Criar pastas | Editor |
| Mover arquivos | Editor |
| Apagar arquivos | **NAO IMPLEMENTADO** — impossivel pelo sistema |

---

## Troubleshooting

### "Falha ao autenticar no Google Drive"

- Verifique se o arquivo `secrets/google_credentials.json` existe e eh valido
- Verifique se o volume esta montado no `docker-compose.yml`
- Teste: `docker compose exec backend cat /run/secrets/google_credentials.json`

### "SEGURANCA: arquivo esta FORA da pasta raiz configurada"

- O arquivo que voce tentou mover nao esta dentro da pasta raiz
- Verifique se `GOOGLE_DRIVE_ROOT_FOLDER_ID` esta correto no `.env`

### "Erro 403: The caller does not have permission"

- O Service Account nao tem acesso a pasta
- Refaca o Passo 6: compartilhe a pasta com o email do Service Account como **Editor**

### "Erro 404: File not found"

- O ID da pasta esta errado ou a pasta foi excluida
- Copie o ID novamente da URL do Drive (Passo 7)

### "Google Drive API has not been used in project"

- A API nao foi ativada. Refaca o Passo 2

### "Rate limit exceeded"

- Google Drive tem limites: ~20.000 requests/100 segundos (leitura), ~3 requests/segundo (escrita)
- Para 5TB de dados, a primeira listagem de pastas grandes pode ser lenta
- Limite de upload: 750 GB/dia

### Logs de auditoria

```bash
# Ver logs de operacoes do Drive
docker compose logs backend | grep "DRIVE AUDIT"
```

---

## Referencia rapida

```bash
# Email do Service Account
cat secrets/google_credentials.json | python3 -c "import sys,json; print(json.load(sys.stdin)['client_email'])"

# Client ID (para delegacao de dominio)
cat secrets/google_credentials.json | python3 -c "import sys,json; print(json.load(sys.stdin)['client_id'])"

# Testar conexao
curl http://localhost:8000/documentos/drive/pasta/SEU_FOLDER_ID

# Ver logs do Drive
docker compose logs backend | grep "DRIVE AUDIT"

# Rebuild apos mudancas
docker compose up -d --build backend
```
