# Deploy — Escritorio Virtual

Instalacao e atualizacao automatizada para servidores Ubuntu/Debian.

## Instalacao rapida (1 comando)

```bash
curl -fsSL https://raw.githubusercontent.com/fcs7/ubiquitous-carnival/master/deploy.sh | sudo bash
```

O script detecta automaticamente o estado do servidor e executa apenas o necessario:

- Instala Docker (se nao tiver)
- Clona o repositorio
- Coleta secrets interativamente (API keys, senhas)
- Configura firewall, SSL e systemd
- Sobe os 7 containers e valida o deploy

## Atualizacao

Execute o mesmo comando. O script:
- **Nunca sobrescreve** o `.env` existente
- Faz `git pull` para atualizar o codigo
- Reconstroi apenas containers que mudaram
- Mostra config atual mascarada e pergunta se quer alterar

## Modo nao-interativo

Para automacao (CI/CD, Ansible, etc):

```bash
# 1. Copie e preencha o template
cp scripts/setup.conf.example setup.conf
nano setup.conf

# 2. Execute
sudo bash scripts/setup.sh --non-interactive --config setup.conf
```

## Opcoes

```
--help                  Mostra ajuda
--version               Mostra versao
--non-interactive       Modo automatico (sem perguntas)
--config <arquivo>      Arquivo de configuracao
--install-dir <caminho> Diretorio de instalacao (default: /opt/escritorio-virtual)
--branch <branch>       Branch do Git (default: master)
--skip-firewall         Nao configura ufw
--skip-ssl              Nao configura HTTPS
--skip-systemd          Nao instala servico systemd
--force-reconfigure     Reconfigura secrets mesmo se ja existem
```

## Requisitos

- Ubuntu ou Debian
- 2GB RAM (minimo)
- 5GB disco livre
- Acesso root (sudo)

## Portas

| Porta | Servico | Acesso externo |
|-------|---------|----------------|
| 22 | SSH | Sim |
| 3000 | Frontend (nginx) | Sim |
| 8080 | Evolution (WhatsApp) | Sim |
| 8000 | Backend (FastAPI) | Nao — via nginx |
| 5432 | PostgreSQL | Nao — interno Docker |
| 6379 | Redis | Nao — interno Docker |

## Apos o deploy

```bash
# Ver status dos containers
docker compose -f /opt/escritorio-virtual/docker-compose.yml ps

# Ver logs
docker compose -f /opt/escritorio-virtual/docker-compose.yml logs -f

# Reiniciar via systemd
sudo systemctl restart escritorio-virtual

# Alterar uma secret
sudo bash /opt/escritorio-virtual/scripts/setup.sh --force-reconfigure
```

## WhatsApp

Apos o deploy, acesse `http://<ip>:8080` para configurar o Evolution API e escanear o QR Code do WhatsApp.

## Google Drive

Se nao configurou durante o deploy, veja [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md).
