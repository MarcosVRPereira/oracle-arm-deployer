#!/bin/bash

# ==============================================================================
#                        CONFIGURAÇÕES PERSONALIZÁVEIS
# ==============================================================================
COMPARTMENT_ID="" 
AVAILABILITY_DOMAIN="" 
SUBNET_ID=""

OCPU_COUNT=4
MEMORY_GB=24
INSTANCE_NAME="ampere-ubuntu-$(date +%Y%m%d-%H%M%S)"
SSH_PUBLIC_KEY_FILE="$HOME/.ssh/SUA-CHAVE-SSH-AQUI.pub"

SLEEP_TIME=30
LOG_DIR="$HOME/oci_logs"
TMUX_SESSION="deploy"

# Configuração de Logs:
# 0 desativa,
# > 0 define a quantidade de sessões mantidas
MAX_LOG_FILES=3

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ==============================================================================
#                             FUNÇÕES DE SUPORTE
# ==============================================================================

init_tmux() {
    if [ -z "$TMUX" ]; then
        echo -e "${GREEN}Iniciando sessão TMUX...${NC}"
        sleep 1
        # Cria a sessão e já renomeia a janela para "script" para ficar mais bonito que "bash"
        tmux new-session -s "$TMUX_SESSION" -n "Script de Criação OCI Ampere" "$0"
        exit 0
    fi
}

setup_logs() {
    # Se MAX_LOG_FILES for 0, usamos /dev/null
    if [ "$MAX_LOG_FILES" -eq 0 ]; then
        ERROR_LOG="/dev/null"
        return
    fi

    mkdir -p "$LOG_DIR"
    
    # Define o arquivo de log único para ESTA sessão
    ERROR_LOG="$LOG_DIR/session_$(date +%Y%m%d_%H%M%S).log"
    echo "--- Nova sessão de execução: $(date) ---" >> "$ERROR_LOG"

    # Lógica para manter apenas N arquivos de log mais recentes
    local log_count=$(ls -1 "$LOG_DIR"/session_*.log 2>/dev/null | wc -l)
    if [ "$log_count" -gt "$MAX_LOG_FILES" ]; then
        # Remove os arquivos mais antigos mantendo os mais recentes conforme configurado
        ls -1tr "$LOG_DIR"/session_*.log | head -n -"$MAX_LOG_FILES" | xargs rm -f
    fi
}

find_ubuntu_image() {
    local cid="$1"
    local img_id=""
    img_id=$(oci compute image list --compartment-id "$cid" --operating-system "Canonical Ubuntu" --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED --sort-order DESC --all 2>/dev/null | jq -r '.data[] | select(."display-name" | contains("aarch64")) | .id' | head -n1)
    
    if [ -z "$img_id" ] || [ "$img_id" == "null" ]; then
        img_id=$(oci compute image list --compartment-id "$cid" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" --shape "VM.Standard.A1.Flex" --all 2>/dev/null | jq -r '.data[] | select(."display-name" | contains("Minimal")) | select(."display-name" | contains("aarch64")) | .id' | head -n1)
    fi
    echo "$img_id"
}

resolve_infra() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}             ${YELLOW}RESOLVENDO INFRAESTRUTURA OCI${NC}             ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -z "$COMPARTMENT_ID" ]; then
        echo -ne "${BLUE}[1/4]${NC} Buscando Compartment... "
        COMPARTMENT_ID=$(oci iam compartment list --all | jq -r '.data[0]."compartment-id"')
        echo -e "${GREEN}OK${NC}"
    fi

    if [ -z "$AVAILABILITY_DOMAIN" ]; then
        echo -ne "${BLUE}[2/4]${NC} Buscando Availability Domain... "
        AVAILABILITY_DOMAIN=$(oci iam availability-domain list --compartment-id "$COMPARTMENT_ID" | jq -r '.data[0].name')
        echo -e "${GREEN}OK${NC}"
    fi

    if [ -z "$SUBNET_ID" ]; then
        echo -ne "${BLUE}[3/4]${NC} Buscando Subnet... "
        SUBNET_ID=$(oci network subnet list --compartment-id "$COMPARTMENT_ID" | jq -r '.data[0].id')
        echo -e "${GREEN}OK${NC}"
    fi

    echo -ne "${BLUE}[4/4]${NC} Buscando Imagem Ubuntu ARM... "
    IMAGE_ID=$(find_ubuntu_image "$COMPARTMENT_ID")
    if [ -z "$IMAGE_ID" ] || [ "$IMAGE_ID" == "null" ]; then
        echo -e "${RED}FALHA${NC}"
        exit 1
    fi
    
    # Busca o nome amigável da imagem para exibir no resumo
    IMAGE_DISPLAY_NAME=$(oci compute image get --image-id "$IMAGE_ID" | jq -r '.data."display-name"')
    echo -e "${GREEN}OK${NC}"
    
    echo ""
    echo -e "${YELLOW}Configuração Completa:${NC}"
    echo "- Instance: $INSTANCE_NAME"
    echo "- Shape:    $OCPU_COUNT OCPU / $MEMORY_GB GB RAM"
    echo "- Imagem:   $IMAGE_DISPLAY_NAME"
    [ "$MAX_LOG_FILES" -gt 0 ] && echo "- Log Sessão: $(basename "$ERROR_LOG")"
    echo "-------------------------------------------------------"
    sleep 2
}

# ==============================================================================
#                             LOOP DE TENTATIVAS
# ==============================================================================

launch_loop() {
    local attempt=0
    local ssh_key=$(cat "$SSH_PUBLIC_KEY_FILE")

    echo -e "${BLUE}Iniciando loop de criação agressivo...${NC}"
    echo -e "Pressione ${RED}CTRL+C${NC} para interromper."
    echo -e "Pressione ${YELLOW}CTRL+B${NC} e depois ${YELLOW}D${NC} para deixar o TMUX rodando em segundo plano."
    echo -e "Digite no terminal ${GREEN}tmux attach -t ${TMUX_SESSION}${NC} para retornar a sessão do TMUX."
    echo ""

    while true; do
        attempt=$((attempt + 1))
        
        # Status: Solicitando
        echo -ne "\r\033[K${BLUE}[Tentativa #$attempt]${NC} $(date '+%H:%M:%S') - ${YELLOW}Solicitando recursos...${NC}"

        local temp_ssh=$(mktemp)
        echo "$ssh_key" > "$temp_ssh"
        
        local out_file=$(mktemp)
        local err_file=$(mktemp)

        oci compute instance launch \
            --compartment-id "$COMPARTMENT_ID" \
            --availability-domain "$AVAILABILITY_DOMAIN" \
            --shape "VM.Standard.A1.Flex" \
            --shape-config "{\"ocpus\":$OCPU_COUNT,\"memoryInGBs\":$MEMORY_GB}" \
            --image-id "$IMAGE_ID" \
            --subnet-id "$SUBNET_ID" \
            --display-name "$INSTANCE_NAME" \
            --assign-public-ip true \
            --ssh-authorized-keys-file "$temp_ssh" \
            --wait-for-state RUNNING \
            --max-wait-seconds 120 > "$out_file" 2> "$err_file"
        
        local exit_code=$?
        local result=$(cat "$out_file")
        local error_output=$(cat "$err_file")
        
        {
            echo "--- Tentativa #$attempt ($(date)) ---"
            echo "Exit Code: $exit_code"
            echo "Saída: $result"
            echo "Erro: $error_output"
            echo "------------------------------------"
        } >> "$ERROR_LOG"

        rm -f "$temp_ssh" "$out_file" "$err_file"

        local check_id=$(echo "$result" | jq -r '.data.id // empty')
        
        if [ $exit_code -eq 0 ] && [ -n "$check_id" ]; then
            echo -e "\n\n${GREEN}=======================================================${NC}"
            echo -e "${GREEN}🎉 SUCESSO! Instância criada na tentativa #$attempt!${NC}"
            echo -e "ID: $check_id"
            echo -e "IP: $(echo "$result" | jq -r '.data."public-ip"')"
            echo -e "${GREEN}=======================================================${NC}"
            exit 0
        fi

        # Status: Falha e Contagem Regressiva
        local msg_err="${RED}Sem capacidade.${NC}"
        if ! echo "$error_output" | grep -qi "capacity"; then
            msg_err="${YELLOW}Erro OCI (ver log).${NC}"
        fi

        # Loop de contagem regressiva
        for ((i=SLEEP_TIME; i>0; i--)); do
            echo -ne "\r\033[K${BLUE}[Tentativa #$attempt]${NC} ${msg_err} Reiniciando em ${YELLOW}${i}s...${NC}"
            sleep 1
        done
    done
}

# ==============================================================================
#                                 EXECUÇÃO INICIAL
# ==============================================================================
init_tmux
setup_logs
resolve_infra
launch_loop