#!/usr/bin/env bash
# =============================================================================
# Escritorio Virtual — Script de instalacao e atualizacao
# Plataforma juridica inteligente para escritorios de advocacia
#
# Uso: bash scripts/setup.sh [opcoes]
# Opcoes: --help, --version, --non-interactive, --config <file>
#         --install-dir <path>, --branch <branch>
#         --skip-firewall, --skip-ssl, --skip-systemd
#         --force-reconfigure
# =============================================================================
set -euo pipefail

# ─── Constantes ──────────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="1.0.0"
readonly SYSTEM_NAME="Escritorio Virtual"
readonly SERVICE_NAME="escritorio-virtual"
readonly REPO_GIT="https://github.com/fcs7/ubiquitous-carnival.git"
readonly DEFAULT_INSTALL_DIR="/opt/escritorio-virtual"
readonly DEFAULT_BRANCH="master"
readonly DATAJUD_DEFAULT_KEY="cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="
readonly DATAJUD_DEFAULT_URL="https://api-publica.datajud.cnj.jus.br"

# Variaveis configuraveis (sobrescritas por args/config)
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
REPO_BRANCH="$DEFAULT_BRANCH"
NON_INTERACTIVE=false
CONFIG_FILE=""
SKIP_FIREWALL=false
SKIP_SSL=false
SKIP_SYSTEMD=false
FORCE_RECONFIGURE=false

# Caminhos derivados (definidos apos parse_args)
STATE_FILE=""
LOG_FILE="/var/log/escritorio-virtual-setup.log"
ENV_FILE=""
SECRETS_DIR=""

# Deteccao de OS
OS_ID=""
OS_VERSION=""

# ─── Cores e formatacao ─────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# ─── Utilitarios de log ─────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${NC}  $(date +%H:%M:%S) $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "$*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $(date +%H:%M:%S) $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "$*"; }
log_warn()    { echo -e "${YELLOW}[AVISO]${NC} $(date +%H:%M:%S) $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "$*"; }
log_error()   { echo -e "${RED}[ERRO]${NC}  $(date +%H:%M:%S) $*" | tee -a "$LOG_FILE" 2>/dev/null || echo "$*" >&2; }
log_step()    { echo -e "\n${BOLD}${CYAN}[$1/$2]${NC} ${BOLD}$3${NC}" | tee -a "$LOG_FILE" 2>/dev/null || echo "[$1/$2] $3"; }

# ─── Utilitarios gerais ─────────────────────────────────────────────────────

# Pergunta sim/nao. Em modo nao-interativo usa o default.
# Uso: confirm "Deseja continuar?" "s" → default sim
#      confirm "Sobrescrever?" "n"   → default nao
confirm() {
    local prompt="$1" default="${2:-n}"
    if $NON_INTERACTIVE; then
        [[ "$default" =~ ^[sS]$ ]] && return 0 || return 1
    fi
    local hint
    if [[ "$default" =~ ^[sS]$ ]]; then hint="[S/n]"; else hint="[s/N]"; fi
    while true; do
        read -rp "$(echo -e "${YELLOW}?${NC} $prompt $hint ") " resp
        resp="${resp:-$default}"
        case "$resp" in
            [sS]|[sS][iI][mM]) return 0 ;;
            [nN]|[nN][aAãÃ][oO]) return 1 ;;
            *) echo "  Responda 's' ou 'n'." ;;
        esac
    done
}

# Le valor do usuario com default
read_value() {
    local prompt="$1" varname="$2" default="${3:-}"
    if $NON_INTERACTIVE; then
        eval "$varname=\"$default\""
        return
    fi
    local display=""
    [[ -n "$default" ]] && display=" ${DIM}(default: $default)${NC}"
    read -rp "$(echo -e "${CYAN}>${NC} ${prompt}${display}: ")" value
    value="${value:-$default}"
    eval "$varname=\"\$value\""
}

# Le secret sem echo
read_secret() {
    local prompt="$1" varname="$2"
    if $NON_INTERACTIVE; then
        eval "$varname=''"
        return
    fi
    read -srp "$(echo -e "${CYAN}>${NC} ${prompt}: ")" value
    echo ""
    eval "$varname=\"\$value\""
}

# Mascara valor sensivel: sk-abc****ef12
mask_value() {
    local val="$1"
    local len=${#val}
    if [[ $len -le 8 ]]; then
        echo "****"
    elif [[ $len -le 16 ]]; then
        echo "${val:0:3}****${val: -4}"
    else
        echo "${val:0:6}****${val: -4}"
    fi
}

# Gera senha aleatoria
gerar_senha() {
    local tamanho="${1:-24}"
    openssl rand -base64 "$((tamanho * 2))" 2>/dev/null | tr -d '/+=\n' | head -c "$tamanho"
}

# Gerenciamento de estado
salvar_estado() {
    local chave="$1" valor="$2"
    mkdir -p "$(dirname "$STATE_FILE")"
    if [[ -f "$STATE_FILE" ]] && grep -q "^${chave}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${chave}=.*|${chave}=${valor}|" "$STATE_FILE"
    else
        echo "${chave}=${valor}" >> "$STATE_FILE"
    fi
    chmod 600 "$STATE_FILE"
}

ler_estado() {
    local chave="$1"
    if [[ -f "$STATE_FILE" ]]; then
        grep "^${chave}=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2- || echo ""
    else
        echo ""
    fi
}

estado_completo() {
    [[ "$(ler_estado "$1")" == "true" ]]
}

# Spinner visual para operacoes longas
spinner() {
    local pid=$1 msg="${2:-Aguarde...}"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC} %s" "${chars:i++%${#chars}:1}" "$msg"
        sleep 0.1
    done
    printf "\r%*s\r" $((${#msg} + 6)) ""
    wait "$pid"
    return $?
}

# ─── Banner ──────────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${BOLD}${CYAN}"
    cat << 'BANNER'
  ╔═══════════════════════════════════════════════╗
  ║         ESCRITORIO VIRTUAL                    ║
  ║     Plataforma Juridica Inteligente           ║
  ╚═══════════════════════════════════════════════╝
BANNER
    echo -e "${NC}${DIM}  Versao $SCRIPT_VERSION — $(date +%Y-%m-%d)${NC}"
    echo ""
}

# ─── Ajuda ───────────────────────────────────────────────────────────────────
print_help() {
    print_banner
    cat << EOF
Uso: bash setup.sh [opcoes]

Opcoes:
  --help                  Mostra esta ajuda
  --version               Mostra a versao do script
  --non-interactive       Modo automatico (sem perguntas)
  --config <arquivo>      Arquivo de configuracao (modo nao-interativo)
  --install-dir <caminho> Diretorio de instalacao (default: $DEFAULT_INSTALL_DIR)
  --branch <branch>       Branch do Git (default: $DEFAULT_BRANCH)
  --skip-firewall         Nao configura firewall (ufw)
  --skip-ssl              Nao configura SSL/HTTPS
  --skip-systemd          Nao instala servico systemd
  --force-reconfigure     Reconfigura secrets mesmo se ja existem

Exemplos:
  # Instalacao interativa padrao
  sudo bash scripts/setup.sh

  # Atualizacao (detecta automaticamente o que ja foi feito)
  sudo bash scripts/setup.sh

  # Instalacao automatica com config
  sudo bash scripts/setup.sh --non-interactive --config setup.conf

  # Instalar em diretorio customizado
  sudo bash scripts/setup.sh --install-dir /srv/escritorio
EOF
}

# ─── Parse de argumentos ────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                print_help
                exit 0 ;;
            --version|-v)
                echo "$SYSTEM_NAME v$SCRIPT_VERSION"
                exit 0 ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift ;;
            --config)
                [[ -z "${2:-}" ]] && { log_error "--config requer um arquivo"; exit 1; }
                CONFIG_FILE="$2"
                shift 2 ;;
            --install-dir)
                [[ -z "${2:-}" ]] && { log_error "--install-dir requer um caminho"; exit 1; }
                INSTALL_DIR="$2"
                shift 2 ;;
            --branch)
                [[ -z "${2:-}" ]] && { log_error "--branch requer um nome"; exit 1; }
                REPO_BRANCH="$2"
                shift 2 ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift ;;
            --skip-ssl)
                SKIP_SSL=true
                shift ;;
            --skip-systemd)
                SKIP_SYSTEMD=true
                shift ;;
            --force-reconfigure)
                FORCE_RECONFIGURE=true
                shift ;;
            *)
                log_error "Opcao desconhecida: $1"
                echo "Use --help para ver as opcoes disponiveis."
                exit 1 ;;
        esac
    done

    # Carrega config file se fornecido
    if [[ -n "$CONFIG_FILE" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "Arquivo de configuracao nao encontrado: $CONFIG_FILE"
            exit 1
        fi
        log_info "Carregando configuracao de $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        NON_INTERACTIVE=true
    fi

    # Define caminhos derivados
    STATE_FILE="$INSTALL_DIR/.ev-state"
    ENV_FILE="$INSTALL_DIR/backend/.env"
    SECRETS_DIR="$INSTALL_DIR/secrets"
}

# ─── Verificacao de root ────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script precisa ser executado como root (sudo)."
        echo "  Uso: sudo bash scripts/setup.sh"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 01/10 — Detectando sistema operacional
# ═══════════════════════════════════════════════════════════════════════════
detect_os() {
    log_step "01" "10" "Detectando sistema operacional..."

    if [[ ! -f /etc/os-release ]]; then
        log_error "Arquivo /etc/os-release nao encontrado."
        log_error "Este script suporta apenas Ubuntu e Debian."
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"

    case "$OS_ID" in
        ubuntu|debian)
            log_success "Sistema detectado: $PRETTY_NAME"
            ;;
        *)
            log_error "Sistema nao suportado: $OS_ID"
            log_error "Este script suporta apenas Ubuntu e Debian."
            exit 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 02/10 — Verificando requisitos do sistema
# ═══════════════════════════════════════════════════════════════════════════
check_system_requirements() {
    log_step "02" "10" "Verificando requisitos do sistema..."
    local erros=0

    # RAM (minimo 2GB)
    local ram_kb
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$(( ram_kb / 1024 / 1024 ))
    if [[ $ram_kb -lt 2000000 ]]; then
        log_warn "RAM disponivel: ${ram_gb}GB (recomendado: 2GB+)"
        log_warn "O sistema pode ficar lento com pouca memoria."
    else
        log_success "RAM: ${ram_gb}GB"
    fi

    # Disco (minimo 5GB livres)
    local disco_livre_kb
    disco_livre_kb=$(df "$(dirname "$INSTALL_DIR")" --output=avail | tail -1 | tr -d ' ')
    local disco_livre_gb=$(( disco_livre_kb / 1024 / 1024 ))
    if [[ $disco_livre_kb -lt 5000000 ]]; then
        log_error "Disco insuficiente: ${disco_livre_gb}GB livres (minimo: 5GB)"
        erros=$((erros + 1))
    else
        log_success "Disco: ${disco_livre_gb}GB livres"
    fi

    # Portas — verifica se estao livres (ignora se ja e nosso container)
    local portas_necessarias=(8000 8080 3000)
    for porta in "${portas_necessarias[@]}"; do
        if ss -tlnp 2>/dev/null | grep -q ":${porta} " && \
           ! ss -tlnp 2>/dev/null | grep ":${porta} " | grep -q "docker"; then
            log_warn "Porta $porta ja em uso por outro processo"
        fi
    done

    # Portas internas (5432, 6379) — nao precisam estar expostas
    for porta in 5432 6379; do
        if ss -tlnp 2>/dev/null | grep -q ":${porta} " && \
           ! ss -tlnp 2>/dev/null | grep ":${porta} " | grep -q "docker"; then
            log_warn "Porta interna $porta em uso — o Docker usara rede interna, mas pode haver conflito"
        fi
    done

    # Internet
    if curl -sf --max-time 5 https://github.com &>/dev/null; then
        log_success "Conexao com a internet: OK"
    elif ping -c1 -W3 github.com &>/dev/null; then
        log_success "Conexao com a internet: OK (via ping)"
    else
        log_error "Sem conexao com a internet"
        erros=$((erros + 1))
    fi

    if [[ $erros -gt 0 ]]; then
        log_error "Requisitos nao atendidos ($erros erro(s)). Corrija e execute novamente."
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 03/10 — Instalando Docker
# ═══════════════════════════════════════════════════════════════════════════
install_docker() {
    log_step "03" "10" "Instalando Docker..."

    # Verificacao dupla: state + realidade
    if estado_completo "DOCKER_INSTALLED" && command -v docker &>/dev/null && docker compose version &>/dev/null; then
        log_success "Docker ja instalado e funcionando, pulando..."
        return 0
    fi

    # Se docker existe mas state nao marcou, so marca
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        log_success "Docker detectado ($(docker --version | cut -d' ' -f3 | tr -d ','))"
        salvar_estado "DOCKER_INSTALLED" "true"
        return 0
    fi

    log_info "Instalando Docker via script oficial..."

    # Instala dependencias minimas
    apt-get update -qq
    apt-get install -y -qq curl ca-certificates gnupg >/dev/null 2>&1

    # Script oficial Docker
    if curl -fsSL https://get.docker.com | bash >> "$LOG_FILE" 2>&1; then
        log_success "Docker instalado com sucesso"
    else
        log_error "Falha ao instalar Docker. Verifique $LOG_FILE"
        exit 1
    fi

    # Habilita e inicia
    systemctl enable --now docker

    # Adiciona usuario ao grupo docker (se via sudo)
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER"
        log_info "Usuario '$SUDO_USER' adicionado ao grupo docker"
        log_info "Faca logout/login para aplicar permissoes do grupo docker"
    fi

    # Verifica
    if docker compose version &>/dev/null; then
        log_success "Docker Compose: $(docker compose version --short)"
        salvar_estado "DOCKER_INSTALLED" "true"
    else
        log_error "docker compose nao disponivel apos instalacao"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 04/10 — Clonando/atualizando repositorio
# ═══════════════════════════════════════════════════════════════════════════
clone_or_update_repo() {
    log_step "04" "10" "Clonando/atualizando repositorio..."

    # Instala git se necessario
    if ! command -v git &>/dev/null; then
        log_info "Instalando git..."
        apt-get update -qq
        apt-get install -y -qq git >/dev/null 2>&1
    fi

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Repositorio existente detectado, atualizando..."
        cd "$INSTALL_DIR"

        # Salva mudancas locais se houver
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            log_warn "Mudancas locais detectadas — salvando com git stash..."
            git stash push -m "ev-setup-$(date +%Y%m%d-%H%M%S)" 2>> "$LOG_FILE"
        fi

        git fetch origin >> "$LOG_FILE" 2>&1
        git checkout "$REPO_BRANCH" >> "$LOG_FILE" 2>&1
        git pull origin "$REPO_BRANCH" >> "$LOG_FILE" 2>&1
        log_success "Repositorio atualizado (branch: $REPO_BRANCH)"
    else
        log_info "Clonando repositorio..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone --branch "$REPO_BRANCH" "$REPO_GIT" "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
        log_success "Repositorio clonado em $INSTALL_DIR"
    fi

    salvar_estado "REPO_CLONED" "true"
    salvar_estado "LAST_DEPLOY" "$(date -Iseconds)"
    salvar_estado "INSTALL_VERSION" "$SCRIPT_VERSION"

    cd "$INSTALL_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 05/10 — Coletando configuracoes e secrets
# ═══════════════════════════════════════════════════════════════════════════
collect_secrets() {
    log_step "05" "10" "Coletando configuracoes e secrets..."

    # Se ja configurado E .env existe E nao e --force-reconfigure
    if estado_completo "ENV_CONFIGURED" && [[ -f "$ENV_FILE" ]] && ! $FORCE_RECONFIGURE; then
        log_info "Configuracoes existentes detectadas."
        show_current_config
        if ! confirm "Deseja alterar alguma configuracao?" "n"; then
            log_success "Configuracoes mantidas intactas."
            return 0
        fi
        edit_existing_config
        return 0
    fi

    # Nova instalacao — coleta tudo
    log_info "Configurando nova instalacao..."
    echo ""

    # --- Banco de dados ---
    echo -e "  ${BOLD}Banco de dados PostgreSQL${NC}"
    local pg_user pg_password pg_db
    read_value "Usuario PostgreSQL" pg_user "muglia"
    read_value "Nome do banco" pg_db "muglia"

    # Gera senha automatica na primeira vez
    pg_password=$(gerar_senha 24)
    log_info "Senha PostgreSQL gerada automaticamente (24 caracteres)"
    echo ""

    # --- APIs obrigatorias ---
    echo -e "  ${BOLD}Chaves de API (obrigatorias)${NC}"
    local openai_key anthropic_key
    while true; do
        read_secret "OpenAI API Key (traducao com gpt-4o-mini)" openai_key
        if [[ -z "$openai_key" ]] && ! $NON_INTERACTIVE; then
            log_warn "OpenAI API Key e obrigatoria para traducao de andamentos."
            continue
        fi
        break
    done
    while true; do
        read_secret "Anthropic API Key (chat juridico Claude)" anthropic_key
        if [[ -z "$anthropic_key" ]] && ! $NON_INTERACTIVE; then
            log_warn "Anthropic API Key e obrigatoria para o assistente juridico."
            continue
        fi
        break
    done
    echo ""

    # --- DataJud ---
    echo -e "  ${BOLD}DataJud CNJ${NC}"
    local datajud_key datajud_url
    read_value "DataJud API Key" datajud_key "$DATAJUD_DEFAULT_KEY"
    datajud_url="$DATAJUD_DEFAULT_URL"
    echo ""

    # --- Evolution (WhatsApp) ---
    echo -e "  ${BOLD}WhatsApp (Evolution API)${NC}"
    local evolution_key
    evolution_key=$(gerar_senha 32)
    log_info "Evolution API Key gerada automaticamente"
    echo ""

    # --- Vindi (opcional) ---
    echo -e "  ${BOLD}Vindi (opcional — pressione Enter para pular)${NC}"
    local vindi_key="" vindi_secret=""
    read_value "Vindi API Key" vindi_key ""
    if [[ -n "$vindi_key" ]]; then
        read_secret "Vindi Webhook Secret" vindi_secret
    fi
    echo ""

    # --- Google Drive (opcional) ---
    echo -e "  ${BOLD}Google Drive (opcional — pressione Enter para pular)${NC}"
    local gdrive_folder_id="" gdrive_pasta_processos gdrive_pasta_clientes
    read_value "Google Drive Root Folder ID" gdrive_folder_id ""
    gdrive_pasta_processos="Processos"
    gdrive_pasta_clientes="Clientes"
    echo ""

    # --- Monta DATABASE_URL ---
    local database_url="postgresql://${pg_user}:${pg_password}@db:5432/${pg_db}"
    local redis_url="redis://redis:6379/0"
    local evolution_url="http://evolution:8080"

    # --- Cria .env ---
    create_env_file \
        "$pg_user" "$pg_password" "$pg_db" \
        "$database_url" "$redis_url" \
        "$openai_key" "$anthropic_key" \
        "$datajud_key" "$datajud_url" \
        "$evolution_url" "$evolution_key" \
        "$vindi_key" "$vindi_secret" \
        "$gdrive_folder_id" "$gdrive_pasta_processos" "$gdrive_pasta_clientes"
}

# Mostra config atual mascarada
show_current_config() {
    echo ""
    echo -e "  ${BOLD}Configuracoes atuais:${NC}"
    while IFS='=' read -r key value; do
        # Ignora comentarios e linhas vazias
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        # Remove espacos
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        local display
        case "$key" in
            *PASSWORD*|*KEY*|*SECRET*)
                if [[ -z "$value" ]]; then
                    display="(nao configurado)"
                else
                    display=$(mask_value "$value")
                fi
                ;;
            *)
                display="$value"
                ;;
        esac
        printf "    %-35s = %s\n" "$key" "$display"
    done < "$ENV_FILE"
    echo ""
}

# Edita config existente individualmente
edit_existing_config() {
    log_info "Modo de edicao individual"
    echo ""

    # Le .env existente num array associativo
    declare -A current_env
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        current_env["$key"]="$value"
    done < "$ENV_FILE"

    # Lista variaveis editaveis
    local editaveis=(
        "OPENAI_API_KEY"
        "ANTHROPIC_API_KEY"
        "DATAJUD_API_KEY"
        "EVOLUTION_API_KEY"
        "VINDI_API_KEY"
        "VINDI_WEBHOOK_SECRET"
        "GOOGLE_DRIVE_ROOT_FOLDER_ID"
        "GOOGLE_DRIVE_PASTA_PROCESSOS"
        "GOOGLE_DRIVE_PASTA_CLIENTES"
    )

    echo "  Variaveis editaveis:"
    local i=1
    for var in "${editaveis[@]}"; do
        local val="${current_env[$var]:-}"
        local display
        if [[ -z "$val" ]]; then
            display="(vazio)"
        elif [[ "$var" =~ KEY|SECRET|PASSWORD ]]; then
            display=$(mask_value "$val")
        else
            display="$val"
        fi
        printf "    %2d. %-35s = %s\n" "$i" "$var" "$display"
        i=$((i + 1))
    done

    echo ""
    echo "  Digite o numero da variavel para editar, ou 0 para sair."
    echo ""

    while true; do
        local escolha
        read_value "Numero (0 = sair)" escolha "0"
        [[ "$escolha" == "0" ]] && break

        if [[ "$escolha" -ge 1 && "$escolha" -le ${#editaveis[@]} ]] 2>/dev/null; then
            local var_name="${editaveis[$((escolha - 1))]}"
            local novo_valor
            if [[ "$var_name" =~ KEY|SECRET|PASSWORD ]]; then
                read_secret "Novo valor para $var_name" novo_valor
            else
                read_value "Novo valor para $var_name" novo_valor ""
            fi
            current_env["$var_name"]="$novo_valor"
            log_success "$var_name atualizado"
        else
            log_warn "Opcao invalida"
        fi
    done

    # Reescreve .env com backup
    backup_env_file
    {
        echo "# Escritorio Virtual — Configuracao"
        echo "# Gerado em $(date -Iseconds)"
        echo "# NUNCA commite este arquivo no git!"
        echo ""
        for key in "${!current_env[@]}"; do
            echo "${key}=${current_env[$key]}"
        done
    } > "$ENV_FILE"
    chmod 600 "$ENV_FILE"

    # Tambem cria .env na raiz para docker-compose (POSTGRES + EVOLUTION)
    create_root_env_from_backend

    log_success "Configuracoes atualizadas"
}

# Backup do .env existente
backup_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        local backup="${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$ENV_FILE" "$backup"
        chmod 600 "$backup"
        log_info "Backup: $backup"
    fi
}

# Cria o .env do backend
create_env_file() {
    local pg_user="$1" pg_password="$2" pg_db="$3"
    local database_url="$4" redis_url="$5"
    local openai_key="$6" anthropic_key="$7"
    local datajud_key="$8" datajud_url="$9"
    local evolution_url="${10}" evolution_key="${11}"
    local vindi_key="${12}" vindi_secret="${13}"
    local gdrive_folder="${14}" gdrive_processos="${15}" gdrive_clientes="${16}"

    backup_env_file

    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" << ENVEOF
# Escritorio Virtual — Configuracao
# Gerado em $(date -Iseconds)
# NUNCA commite este arquivo no git!

# Banco de dados
DATABASE_URL=${database_url}
REDIS_URL=${redis_url}

# OpenAI (traducao de andamentos juridicos)
OPENAI_API_KEY=${openai_key}

# Anthropic (assistente juridico Claude)
ANTHROPIC_API_KEY=${anthropic_key}

# DataJud CNJ (consulta de processos)
DATAJUD_API_KEY=${datajud_key}
DATAJUD_BASE_URL=${datajud_url}

# Evolution API (WhatsApp)
EVOLUTION_API_URL=${evolution_url}
EVOLUTION_API_KEY=${evolution_key}

# Vindi (financeiro — opcional)
VINDI_API_KEY=${vindi_key}
VINDI_WEBHOOK_SECRET=${vindi_secret}

# Google Drive (gestao de documentos — opcional)
GOOGLE_DRIVE_ROOT_FOLDER_ID=${gdrive_folder}
GOOGLE_DRIVE_PASTA_PROCESSOS=${gdrive_processos}
GOOGLE_DRIVE_PASTA_CLIENTES=${gdrive_clientes}
ENVEOF

    chmod 600 "$ENV_FILE"
    log_success "Arquivo $ENV_FILE criado (chmod 600)"

    # .env raiz para docker-compose (POSTGRES vars + EVOLUTION_API_KEY)
    cat > "$INSTALL_DIR/.env" << ROOTENV
# Docker Compose — variaveis de ambiente
# Gerado pelo setup.sh em $(date -Iseconds)
POSTGRES_USER=${pg_user}
POSTGRES_PASSWORD=${pg_password}
POSTGRES_DB=${pg_db}
EVOLUTION_API_KEY=${evolution_key}
ROOTENV
    chmod 600 "$INSTALL_DIR/.env"

    # Salva hash da senha postgres para detectar mudancas futuras
    local pg_hash
    pg_hash=$(echo -n "$pg_password" | sha256sum | cut -d' ' -f1)
    salvar_estado "POSTGRES_PASSWORD_HASH" "sha256:$pg_hash"
    salvar_estado "ENV_CONFIGURED" "true"
}

# Extrai vars do backend .env para criar .env raiz (usado em edicao)
create_root_env_from_backend() {
    local pg_user pg_password pg_db ev_key
    # Extrai do DATABASE_URL
    local db_url
    db_url=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d'=' -f2-)
    # postgresql://user:pass@host:port/db
    pg_user=$(echo "$db_url" | sed -n 's|postgresql://\([^:]*\):.*|\1|p')
    pg_password=$(echo "$db_url" | sed -n 's|postgresql://[^:]*:\([^@]*\)@.*|\1|p')
    pg_db=$(echo "$db_url" | sed -n 's|.*/\([^?]*\).*|\1|p')
    ev_key=$(grep "^EVOLUTION_API_KEY=" "$ENV_FILE" | cut -d'=' -f2-)

    cat > "$INSTALL_DIR/.env" << ROOTENV
# Docker Compose — variaveis de ambiente
# Atualizado pelo setup.sh em $(date -Iseconds)
POSTGRES_USER=${pg_user}
POSTGRES_PASSWORD=${pg_password}
POSTGRES_DB=${pg_db}
EVOLUTION_API_KEY=${ev_key}
ROOTENV
    chmod 600 "$INSTALL_DIR/.env"
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 06/10 — Configurando Google Drive
# ═══════════════════════════════════════════════════════════════════════════
setup_google_credentials() {
    log_step "06" "10" "Configurando Google Drive..."

    local creds_file="$SECRETS_DIR/google_credentials.json"

    # Se ja configurado e arquivo existe
    if estado_completo "GOOGLE_CREDS_CONFIGURED" && [[ -f "$creds_file" ]]; then
        log_success "Credenciais Google Drive ja configuradas."
        if ! confirm "Deseja substituir as credenciais existentes?" "n"; then
            return 0
        fi
    fi

    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"

    # Em modo nao-interativo, usa GOOGLE_CREDENTIALS_FILE do config
    if $NON_INTERACTIVE; then
        if [[ -n "${GOOGLE_CREDENTIALS_FILE:-}" && -f "${GOOGLE_CREDENTIALS_FILE:-}" ]]; then
            cp "$GOOGLE_CREDENTIALS_FILE" "$creds_file"
            chmod 600 "$creds_file"
            salvar_estado "GOOGLE_CREDS_CONFIGURED" "true"
            log_success "Credenciais Google Drive copiadas"
        else
            log_info "Google Drive nao configurado (opcional)."
            salvar_estado "GOOGLE_CREDS_CONFIGURED" "false"
        fi
        return 0
    fi

    echo ""
    echo -e "  ${BOLD}Google Drive Service Account${NC}"
    echo "  Para usar a integracao com Google Drive, voce precisa de um"
    echo "  arquivo JSON de credenciais de Service Account."
    echo "  Consulte: docs/GOOGLE_DRIVE_SETUP.md"
    echo ""

    if ! confirm "Deseja configurar Google Drive agora?" "n"; then
        log_info "Google Drive pulado (pode configurar depois)."
        salvar_estado "GOOGLE_CREDS_CONFIGURED" "false"
        return 0
    fi

    local src_file
    read_value "Caminho do arquivo JSON de credenciais" src_file ""

    if [[ -z "$src_file" || ! -f "$src_file" ]]; then
        log_warn "Arquivo nao encontrado: $src_file"
        salvar_estado "GOOGLE_CREDS_CONFIGURED" "false"
        return 0
    fi

    # Valida JSON
    if ! python3 -c "import json; json.load(open('$src_file'))" 2>/dev/null && \
       ! jq empty "$src_file" 2>/dev/null; then
        log_error "Arquivo nao e um JSON valido: $src_file"
        salvar_estado "GOOGLE_CREDS_CONFIGURED" "false"
        return 0
    fi

    cp "$src_file" "$creds_file"
    chmod 600 "$creds_file"
    salvar_estado "GOOGLE_CREDS_CONFIGURED" "true"
    log_success "Credenciais Google Drive instaladas em $creds_file"
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 07/10 — Configurando firewall (ufw)
# ═══════════════════════════════════════════════════════════════════════════
configure_firewall() {
    log_step "07" "10" "Configurando firewall (ufw)..."

    if $SKIP_FIREWALL; then
        log_info "Firewall pulado (--skip-firewall)"
        return 0
    fi

    # Verificacao dupla
    if estado_completo "FIREWALL_CONFIGURED" && command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        log_success "Firewall ja configurado e ativo, pulando..."
        return 0
    fi

    # Instala ufw se necessario
    if ! command -v ufw &>/dev/null; then
        log_info "Instalando ufw..."
        apt-get update -qq
        apt-get install -y -qq ufw >/dev/null 2>&1
    fi

    log_info "Configurando regras do firewall..."

    # Regras — so portas necessarias
    ufw --force reset >> "$LOG_FILE" 2>&1
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # SSH — essencial
    ufw allow 22/tcp comment "SSH" >> "$LOG_FILE" 2>&1

    # Frontend (porta alta — seguro)
    ufw allow 3000/tcp comment "Escritorio Virtual Frontend" >> "$LOG_FILE" 2>&1

    # Evolution webhook (recebe msgs do WhatsApp)
    ufw allow 8080/tcp comment "Evolution API WhatsApp" >> "$LOG_FILE" 2>&1

    # NAO abre:
    # 5432 — PostgreSQL (so acesso interno Docker)
    # 6379 — Redis (so acesso interno Docker)
    # 8000 — Backend (acesso via nginx no container frontend)
    log_info "Portas internas bloqueadas externamente: 5432 (PostgreSQL), 6379 (Redis), 8000 (Backend)"

    # Ativa
    if $NON_INTERACTIVE; then
        ufw --force enable >> "$LOG_FILE" 2>&1
    else
        echo ""
        echo -e "  ${BOLD}Regras do firewall:${NC}"
        echo "    PERMITIDO: 22 (SSH), 3000 (Frontend), 8080 (Evolution)"
        echo "    BLOQUEADO: 5432 (PostgreSQL), 6379 (Redis), 8000 (Backend)"
        echo ""
        if confirm "Ativar firewall com estas regras?" "s"; then
            ufw --force enable >> "$LOG_FILE" 2>&1
        else
            log_warn "Firewall NAO ativado. Ative manualmente: sudo ufw enable"
            salvar_estado "FIREWALL_CONFIGURED" "false"
            return 0
        fi
    fi

    salvar_estado "FIREWALL_CONFIGURED" "true"
    log_success "Firewall configurado e ativo"
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 08/10 — Configurando SSL (Let's Encrypt)
# ═══════════════════════════════════════════════════════════════════════════
setup_ssl() {
    log_step "08" "10" "Configurando SSL (Let's Encrypt)..."

    if $SKIP_SSL; then
        log_info "SSL pulado (--skip-ssl)"
        return 0
    fi

    if estado_completo "SSL_CONFIGURED"; then
        log_success "SSL ja configurado, pulando..."
        return 0
    fi

    local dominio="" email=""

    if $NON_INTERACTIVE; then
        dominio="${SSL_DOMAIN:-}"
        email="${SSL_EMAIL:-}"
    else
        if ! confirm "Voce tem um dominio apontando para este servidor?" "n"; then
            log_info "SSL pulado. Execute novamente quando tiver um dominio configurado."
            salvar_estado "SSL_CONFIGURED" "false"
            return 0
        fi
        read_value "Dominio (ex: app.escritorio.com.br)" dominio ""
        read_value "Email para certificado SSL" email ""
    fi

    if [[ -z "$dominio" ]]; then
        log_info "SSL pulado — nenhum dominio fornecido."
        salvar_estado "SSL_CONFIGURED" "false"
        return 0
    fi

    # Instala certbot
    log_info "Instalando certbot..."
    apt-get update -qq
    apt-get install -y -qq certbot >/dev/null 2>&1

    # Gera certificado standalone (para antes de ter nginx como container)
    log_info "Gerando certificado SSL para $dominio..."
    local certbot_args=(certonly --standalone --non-interactive --agree-tos -d "$dominio")
    [[ -n "$email" ]] && certbot_args+=(--email "$email") || certbot_args+=(--register-unsafely-without-email)

    if certbot "${certbot_args[@]}" >> "$LOG_FILE" 2>&1; then
        log_success "Certificado SSL gerado para $dominio"

        # Cria nginx ssl config
        local ssl_conf="$INSTALL_DIR/frontend/nginx-ssl.conf"
        cat > "$ssl_conf" << SSLCONF
server {
    listen 80;
    server_name $dominio;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $dominio;

    ssl_certificate /etc/letsencrypt/live/$dominio/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$dominio/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /usr/share/nginx/html;
    index index.html;

    resolver 127.0.0.11 valid=10s;
    set \$backend http://backend:8000;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /agentes/ { proxy_pass \$backend; }
    location /assistente/ { proxy_pass \$backend; }
    location /clientes/ { proxy_pass \$backend; }
    location /conversas/ { proxy_pass \$backend; }
    location /financeiro/ { proxy_pass \$backend; }
    location /prazos/ { proxy_pass \$backend; }
    location /processos/ { proxy_pass \$backend; }
    location /tags/ { proxy_pass \$backend; }
    location /vindi/ { proxy_pass \$backend; }
    location /webhooks/ { proxy_pass \$backend; }
    location /whatsapp/ { proxy_pass \$backend; }
    location /health { proxy_pass \$backend; }
}
SSLCONF

        # Cron para renovacao automatica
        if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
            (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'docker compose -f $INSTALL_DIR/docker-compose.yml restart frontend'") | crontab -
            log_info "Cron de renovacao SSL configurado (diario as 3h)"
        fi

        salvar_estado "SSL_CONFIGURED" "true"
        salvar_estado "SSL_DOMAIN" "$dominio"
    else
        log_error "Falha ao gerar certificado SSL. Verifique:"
        log_error "  1. O dominio $dominio aponta para este servidor?"
        log_error "  2. A porta 80 esta livre?"
        log_error "  Detalhes em $LOG_FILE"
        salvar_estado "SSL_CONFIGURED" "false"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 09/10 — Configurando servico systemd
# ═══════════════════════════════════════════════════════════════════════════
create_systemd_service() {
    log_step "09" "10" "Configurando servico systemd..."

    if $SKIP_SYSTEMD; then
        log_info "Systemd pulado (--skip-systemd)"
        return 0
    fi

    # Verificacao dupla
    if estado_completo "SYSTEMD_CONFIGURED" && systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
        log_success "Servico systemd ja configurado, pulando..."
        return 0
    fi

    local service_src="$INSTALL_DIR/scripts/escritorio-virtual.service"
    local service_dest="/etc/systemd/system/${SERVICE_NAME}.service"

    if [[ ! -f "$service_src" ]]; then
        log_error "Template systemd nao encontrado: $service_src"
        return 1
    fi

    # Substitui placeholder pelo diretorio real
    sed "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$service_src" > "$service_dest"

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >> "$LOG_FILE" 2>&1

    salvar_estado "SYSTEMD_CONFIGURED" "true"
    log_success "Servico systemd instalado e habilitado: $SERVICE_NAME"
    log_info "Comandos: systemctl {start|stop|restart|status} $SERVICE_NAME"
}

# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 10/10 — Construindo e iniciando containers
# ═══════════════════════════════════════════════════════════════════════════
build_and_start() {
    log_step "10" "10" "Construindo e iniciando containers..."

    cd "$INSTALL_DIR"

    # Garante que o secrets dir existe (docker-compose monta volume)
    mkdir -p "$SECRETS_DIR"
    if [[ ! -f "$SECRETS_DIR/google_credentials.json" ]]; then
        echo '{}' > "$SECRETS_DIR/google_credentials.json"
    fi

    log_info "Baixando imagens base..."
    docker compose pull --quiet >> "$LOG_FILE" 2>&1 || true

    log_info "Construindo e iniciando containers (isso pode levar alguns minutos)..."

    # Build em background com spinner
    docker compose up -d --build >> "$LOG_FILE" 2>&1 &
    local build_pid=$!
    spinner "$build_pid" "Construindo containers..."

    if [[ $? -eq 0 ]]; then
        log_success "Containers iniciados com sucesso"
    else
        log_error "Falha ao iniciar containers. Verifique: docker compose logs"
        log_error "Log completo em $LOG_FILE"
        return 1
    fi

    # Validacao pos-deploy
    validate_deployment
}

# ─── Validacao pos-deploy ────────────────────────────────────────────────────
validate_deployment() {
    echo ""
    log_info "Validando deploy..."
    echo ""

    local total=7 ok=0 falhas=0

    # Helper para health check com retry
    check_service() {
        local nome="$1" cmd="$2" timeout="${3:-30}"
        local elapsed=0
        while [[ $elapsed -lt $timeout ]]; do
            if eval "$cmd" &>/dev/null; then
                printf "  ${GREEN}✔${NC} %-15s OK\n" "$nome"
                ok=$((ok + 1))
                return 0
            fi
            sleep 2
            elapsed=$((elapsed + 2))
        done
        printf "  ${RED}✘${NC} %-15s FALHOU (timeout ${timeout}s)\n" "$nome"
        falhas=$((falhas + 1))
        return 1
    }

    cd "$INSTALL_DIR"

    check_service "PostgreSQL" "docker compose exec -T db pg_isready -U muglia" 30 || true
    check_service "Redis" "docker compose exec -T redis redis-cli ping | grep -q PONG" 10 || true
    check_service "Backend" "curl -sf http://localhost:8000/health" 45 || true
    check_service "Worker" "docker compose ps worker --format '{{.State}}' | grep -q running" 10 || true
    check_service "Beat" "docker compose ps beat --format '{{.State}}' | grep -q running" 10 || true
    check_service "Evolution" "curl -sf http://localhost:8080/" 30 || true
    check_service "Frontend" "curl -sf http://localhost:3000/" 30 || true

    echo ""
    if [[ $falhas -eq 0 ]]; then
        log_success "Todos os $total servicos estao funcionando!"
    else
        log_warn "$ok/$total servicos OK, $falhas com falha"
        log_info "Verifique logs: docker compose logs <servico>"
    fi
}

# ─── Resumo final ────────────────────────────────────────────────────────────
print_summary() {
    local dominio
    dominio=$(ler_estado "SSL_DOMAIN")

    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          ESCRITORIO VIRTUAL — Deploy Completo            ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${BOLD}URLs de acesso:${NC}"
    if [[ -n "$dominio" ]]; then
        echo "    Frontend:  https://$dominio/"
        echo "    API:       https://$dominio/health"
    else
        echo "    Frontend:  http://<ip-do-servidor>:3000/"
        echo "    API:       http://<ip-do-servidor>:8000/health"
    fi
    echo "    Evolution: http://<ip-do-servidor>:8080/"
    echo ""

    echo -e "  ${BOLD}Arquivos importantes:${NC}"
    echo "    Configuracao:  $ENV_FILE"
    echo "    Estado:        $STATE_FILE"
    echo "    Logs setup:    $LOG_FILE"
    echo "    Credenciais:   $SECRETS_DIR/"
    echo ""

    echo -e "  ${BOLD}Comandos uteis:${NC}"
    echo "    docker compose -f $INSTALL_DIR/docker-compose.yml logs -f"
    echo "    docker compose -f $INSTALL_DIR/docker-compose.yml ps"
    echo "    systemctl status $SERVICE_NAME"
    echo "    systemctl restart $SERVICE_NAME"
    echo ""

    if ! estado_completo "GOOGLE_CREDS_CONFIGURED"; then
        echo -e "  ${YELLOW}Nota:${NC} Google Drive nao configurado."
        echo "    Consulte: docs/GOOGLE_DRIVE_SETUP.md"
        echo ""
    fi

    echo -e "  ${YELLOW}Importante:${NC} Para usar o WhatsApp, acesse o Evolution API"
    echo "    e escaneie o QR Code para conectar o numero."
    echo ""

    echo -e "${DIM}  Instalacao concluida em $(date '+%d/%m/%Y as %H:%M:%S')${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN — Orquestrador
# ═══════════════════════════════════════════════════════════════════════════
main() {
    parse_args "$@"

    # Inicializa log
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/escritorio-virtual-setup.log"
    echo "=== $SYSTEM_NAME Setup — $(date -Iseconds) ===" >> "$LOG_FILE"

    print_banner
    check_root

    detect_os
    check_system_requirements
    install_docker
    clone_or_update_repo
    collect_secrets
    setup_google_credentials
    configure_firewall
    setup_ssl
    create_systemd_service
    build_and_start
    print_summary

    salvar_estado "LAST_DEPLOY" "$(date -Iseconds)"
}

main "$@"
