#!/usr/bin/env bash
# Copyright (c) 2021-2025 ebritzke
# Author: Eduardo Britzke (ebritzke)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

# Este script fornece uma interface gráfica para gerenciar várias tarefas de administração do Proxmox VE
# Inclui funções para backup do host, atualização de repositórios, limpeza de LXCs, entre outras operações

# Definição das cores da paleta (estilo monitor de fósforo)
COLOR_GREEN="\033[32m"                  # Verde fósforo
COLOR_DARK_GREEN="\033[32;1m"           # Verde fósforo brilhante
COLOR_MOSS="\033[38;5;34m"              # Verde alternativo
COLOR_TEAL="\033[38;5;36m"              # Verde azulado
COLOR_NAVY="\033[38;5;22m"              # Verde escuro
COLOR_WHITE="\033[32m"                  # Texto em verde (não branco)
COLOR_BOLD="\033[1m"                    # Negrito
COLOR_RESET="\033[0m"                   # Reset para cor padrão
BOX_HLINE="━"                           # Linha horizontal para caixas
BOX_VLINE="┃"                           # Linha vertical para caixas
BOX_TLCORNER="┏"                        # Canto superior esquerdo
BOX_TRCORNER="┓"                        # Canto superior direito
BOX_BLCORNER="┗"                        # Canto inferior esquerdo
BOX_BRCORNER="┛"                        # Canto inferior direito

# Define o fundo preto para toda a aplicação
echo -e "\033[40m"                      # Fundo preto

# Função para exibir o cabeçalho do programa com arte ASCII
function header_info {
  clear
  local header_width=60
  echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}${BOX_TLCORNER}$(printf "%${header_width}s" "" | tr " " "${BOX_HLINE}")${BOX_TRCORNER}${COLOR_RESET}"
  
  # Logo Proxmox sem barras laterais
  echo -e "${COLOR_GREEN}  ██████╗ ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ ██████╗ ██╗  ██╗  ${COLOR_RESET}"
  echo -e "${COLOR_GREEN}  ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝████╗ ████║██╔═══██╗╚██╗██╔╝  ${COLOR_RESET}"
  echo -e "${COLOR_MOSS}  ██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██╔████╔██║██║   ██║ ╚███╔╝   ${COLOR_RESET}"
  echo -e "${COLOR_MOSS}  ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║╚██╔╝██║██║   ██║ ██╔██╗   ${COLOR_RESET}"
  echo -e "${COLOR_TEAL}  ██║     ██║  ██║╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗  ${COLOR_RESET}"
  echo -e "${COLOR_TEAL}  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝  ${COLOR_RESET}"
  echo -e ""
  
  # Centraliza o título
  local title="GERENCIADOR DE FERRAMENTAS PROXMOX"
  local title_length=${#title}
  local spaces=$(( (header_width - title_length) / 2 ))
  local title_padding="$(printf "%${spaces}s" "")"
  
  echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}${BOX_VLINE}${COLOR_RESET}${COLOR_WHITE}${COLOR_BOLD}${title_padding}${title}${title_padding}${COLOR_RESET}${COLOR_DARK_GREEN}${COLOR_BOLD}${BOX_VLINE}${COLOR_RESET}"
  echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}${BOX_VLINE}${COLOR_RESET}${content_padding}${COLOR_WHITE}                                    ${content_padding}${COLOR_DARK_GREEN}${COLOR_BOLD}${BOX_VLINE}${COLOR_RESET}"
  echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}${BOX_BLCORNER}$(printf "%${header_width}s" "" | tr " " "${BOX_HLINE}")${BOX_BRCORNER}${COLOR_RESET}"
  echo ""
}

# Função para backup do host
# Permite ao usuário selecionar diretórios específicos para backup
# e define o local onde o backup será armazenado
function host_backup {
  # Variáveis locais para armazenar caminhos e configurações do backup
  local BACKUP_PATH     # Diretório onde o backup será salvo
  local DIR             # Diretório de trabalho a ser analisado
  local DIR_DASH        # Versão do diretório com traços em vez de barras
  local BACKUP_FILE     # Nome do arquivo de backup
  local selected_directories=()  # Array para armazenar diretórios selecionados

  # Solicita ao usuário o diretório onde o backup será salvo
  # Se o usuário cancelar (pressionar ESC), a função retorna
  # Se nenhum valor for fornecido, usa /root/ como padrão
  echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}=== Diretório para backup: ===${COLOR_RESET}"
  echo -e "Padrão: /root/"
  echo -e "Ex: /mnt/backups/"
  read -p "Digite o caminho: " BACKUP_PATH
  BACKUP_PATH="${BACKUP_PATH:-/root/}"

  # Solicita ao usuário o diretório de trabalho a ser analisado
  # Se nenhum valor for fornecido, usa /etc/ como padrão
  echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}=== Diretório de trabalho: ===${COLOR_RESET}"
  echo -e "Padrão: /etc/"
  echo -e "Ex: /root/, /var/lib/pve-cluster/"
  read -p "Digite o caminho: " DIR
  DIR="${DIR:-/etc/}"

  # Converte barras (/) em traços (-) para usar no nome do arquivo
  DIR_DASH=$(echo "$DIR" | tr '/' '-')
  # Cria o nome do arquivo de backup usando o hostname e o diretório
  BACKUP_FILE="$(hostname)${DIR_DASH}backup"

  # Define a variável DIRNAME para uso no cálculo do tamanho da janela
  local DIRNAME="$DIR"

  # Cria um menu com todos os arquivos/diretórios dentro do diretório de trabalho
  # Cada item é adicionado ao array CTID_MENU com formato para o whiptail
  # O formato é: [nome_do_item] [caminho_completo] [estado_inicial=OFF]
  local CTID_MENU=()
  while read -r dir; do
    CTID_MENU+=("$(basename "$dir")" "$dir " "OFF")
  done < <(ls -d "${DIR}"*)

  # Exibe um menu de seleção múltipla para o usuário escolher quais itens fazer backup
  # O loop continua até que pelo menos um item seja selecionado
  local HOST_BACKUP
  while [ -z "${HOST_BACKUP:+x}" ]; do
    # Exibe o menu de seleção e armazena as escolhas do usuário
    header_info
    echo -e "${COLOR_DARK_GREEN}${COLOR_BOLD}=== Trabalhando no diretório ${DIR} ===${COLOR_RESET}"
    echo -e "\nSelecione os arquivos/diretórios para backup (digite os números separados por espaço):\n"
    
    # Exibe os itens disponíveis
    local i=1
    local item_map=()
    for ((j=0; j<${#CTID_MENU[@]}; j+=3)); do
      echo -e "$i) ${CTID_MENU[j]}"
      item_map[$i]=${CTID_MENU[j]}
      ((i++))
    done
    
    read -p "Sua seleção: " selections
    
    # Processa as seleções
    for num in $selections; do
      if [[ $num =~ ^[0-9]+$ ]] && [ $num -ge 1 ] && [ $num -lt $i ]; then
        HOST_BACKUP="${HOST_BACKUP} ${item_map[$num]}"
      fi
    done

    # Processa cada item selecionado e adiciona ao array de diretórios selecionados
    # Remove as aspas duplas da saída do whiptail
    for selected_dir in ${HOST_BACKUP//\"/}; do
      selected_directories+=("${DIR}$selected_dir")
    done
  done

  # Exibe informações sobre o backup que será realizado
  header_info
  echo -e "${COLOR_WHITE}Isso criará um backup em ${COLOR_GREEN}${COLOR_BOLD}$BACKUP_PATH${COLOR_RESET}${COLOR_WHITE} para estes arquivos e diretórios ${COLOR_GREEN}${COLOR_BOLD}${selected_directories[*]}${COLOR_RESET}"
  read -p "Pressione ENTER para continuar..."
  
  # Executa o backup usando tar
  header_info
  echo "Trabalhando..."
  # Cria um arquivo tar comprimido com gzip (-z) contendo todos os diretórios selecionados
  # O nome do arquivo inclui a data atual no formato YYYY_MM_DD
  tar -czf "$BACKUP_PATH$BACKUP_FILE-$(date +%Y_%m_%d).tar.gz" --absolute-names "${selected_directories[@]}"
  
  # Exibe mensagem de conclusão e aviso sobre armazenamento de backups
  header_info
  echo -e "\n${COLOR_GREEN}${COLOR_BOLD}Concluído${COLOR_RESET}"
  echo -e "${COLOR_MOSS}${COLOR_BOLD}\nUm backup se torna ineficaz quando permanece armazenado no host.${COLOR_RESET}\n"
  sleep 2
}

# Função para atualizar repositórios
# Atualiza os repositórios em todos os containers LXC que usam apt
# Substitui referências de 'tteck/Proxmox' por 'community-scripts/ProxmoxVE'
function update_repo {
  header_info
  # Cria uma caixa com bordas para o título
  local title_width=42
  local padding=$(( (title_width - 38) / 2 ))
  local left_padding="$(printf "%${padding}s" "")"
  
  echo -e "${COLOR_TEAL}${BOX_TLCORNER}$(printf "%${title_width}s" "" | tr " " "${BOX_HLINE}")${BOX_TRCORNER}${COLOR_RESET}"
  echo -e "${COLOR_TEAL}${BOX_VLINE}${COLOR_WHITE}${COLOR_BOLD}${left_padding}ATUALIZANDO REPOSITÓRIOS DOS CONTAINERS${left_padding}${COLOR_RESET}${COLOR_TEAL}${BOX_VLINE}${COLOR_RESET}"
  echo -e "${COLOR_TEAL}${BOX_BLCORNER}$(printf "%${title_width}s" "" | tr " " "${BOX_HLINE}")${BOX_BRCORNER}${COLOR_RESET}"
  echo ""
  
  # Itera sobre todos os containers LXC listados pelo comando 'pct list'
  # NR>1 pula o cabeçalho da saída do comando
  for container in $(pct list | awk '{if(NR>1) print $1}'); do
    # Verifica se o container usa apt (sistemas baseados em Debian/Ubuntu)
    if pct exec "$container" -- which apt >/dev/null 2>&1; then
      # Verifica se o arquivo /usr/bin/update existe no container
      if pct exec "$container" -- test -f /usr/bin/update; then
        # Informa que está atualizando o arquivo
        echo -e "${COLOR_TEAL}[Info]${COLOR_RESET} Atualizando /usr/bin/update no container ${COLOR_GREEN}${COLOR_BOLD}$container${COLOR_RESET}"
        # Executa o comando sed para substituir o repositório antigo pelo novo
        pct exec "$container" -- bash -c "sed -i 's/tteck\\/Proxmox/community-scripts\\/ProxmoxVE/g' /usr/bin/update"

        # Verifica se a atualização foi bem-sucedida
        if pct exec "$container" -- grep -q "community-scripts/ProxmoxVE" /usr/bin/update; then
          echo -e "${COLOR_GREEN}[Sucesso]${COLOR_RESET} /usr/bin/update atualizado em ${COLOR_GREEN}${COLOR_BOLD}$container${COLOR_RESET}.\n"
        else
          echo -e "${COLOR_NAVY}[Erro]${COLOR_RESET} /usr/bin/update em ${COLOR_GREEN}${COLOR_BOLD}$container${COLOR_RESET} não pôde ser atualizado.\n"
        fi
      else
        # Informa que o arquivo não foi encontrado
        echo -e "${COLOR_NAVY}[Erro]${COLOR_RESET} /usr/bin/update não encontrado no container ${COLOR_GREEN}${COLOR_BOLD}$container${COLOR_RESET}.\n"
      fi
    else
      # Informa que está pulando containers que não são baseados em Debian/Ubuntu
      echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Pulando ${COLOR_TEAL}${COLOR_BOLD}$container${COLOR_RESET} (não é Debian/Ubuntu)\n"
    fi
  done

  # Exibe mensagem de conclusão do processo
  echo -e "${COLOR_GREEN}${COLOR_BOLD}O processo está completo. Os repositórios foram alterados para community-scripts/ProxmoxVE.${COLOR_RESET}\n"
  read -p "Pressione ENTER para continuar..."
}

# Função para limpar LXCs
# Limpa logs, cache e atualiza listas apt nos containers LXC selecionados
function clean_lxcs() {
  # Usando as cores definidas no início do script
  # Ícone de verificação para uso em mensagens
  CM='\xE2\x9C\x94\033'
  header_info
  echo "Carregando..."
  NODE=$(hostname)
  EXCLUDE_MENU=()
  MSG_MAX_LENGTH=0
  while read -r TAG ITEM; do
    OFFSET=2
    ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
    EXCLUDE_MENU+=("$TAG" "$ITEM " "OFF")
  done < <(pct list | awk 'NR>1')
  excluded_containers=$(whiptail --backtitle "Gerenciador Proxmox" --title "Containers em $NODE" --checklist "\nSelecione containers para pular a limpeza:\n" \
    16 $((MSG_MAX_LENGTH + 23)) 6 "${EXCLUDE_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"')

  function clean_container() {
    container=$1
    header_info
    name=$(pct exec "$container" hostname)
    echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Limpando ${COLOR_BOLD}${name}${COLOR_RESET} \n"
    pct exec "$container" -- bash -c "apt-get -y --purge autoremove && apt-get -y autoclean && \
    # Início do código incorporado (anteriormente baixado via curl)
    echo 'Limpando logs antigos...' && \
    find /var/log -type f -regex '.*\.gz$' -delete && \
    find /var/log -type f -regex '.*\.[0-9]$' -delete && \
    find /var/log -type f -regex '.*\.old$' -delete && \
    truncate -s 0 /var/log/*.log && \
    truncate -s 0 /var/log/**/*.log && \
    echo 'Limpando cache de pacotes...' && \
    apt-get clean && \
    journalctl --rotate && \
    journalctl --vacuum-time=1d && \
    echo 'Limpeza concluída!' && \
    # Fim do código incorporado
    rm -rf /var/lib/apt/lists/* && apt-get update"
  }
  for container in $(pct list | awk '{if(NR>1) print $1}'); do
    if [[ " ${excluded_containers[@]} " =~ " $container " ]]; then
      header_info
      echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Pulando ${COLOR_TEAL}${COLOR_BOLD}$container${COLOR_RESET}"
      sleep 1
    else
      os=$(pct config "$container" | awk '/^ostype/ {print $2}')
      if [ "$os" != "debian" ] && [ "$os" != "ubuntu" ]; then
        header_info
        echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Pulando ${COLOR_BOLD}${name}${COLOR_RESET} ${COLOR_NAVY}$container não é Debian ou Ubuntu${COLOR_RESET} \n"
        sleep 1
        continue
      fi

      status=$(pct status "$container")
      template=$(pct config "$container" | grep -q "template:" && echo "true" || echo "false")
      if [ "$template" == "false" ] && [ "$status" == "status: stopped" ]; then
        echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Iniciando ${COLOR_TEAL}${COLOR_BOLD}$container${COLOR_RESET} \n"
        pct start "$container"
        echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Aguardando ${COLOR_TEAL}${COLOR_BOLD}$container${COLOR_RESET}${COLOR_GREEN} iniciar${COLOR_RESET} \n"
        sleep 5
        clean_container "$container"
        echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Desligando ${COLOR_TEAL}${COLOR_BOLD}$container${COLOR_RESET} \n"
        pct shutdown "$container" &
      elif [ "$status" == "status: running" ]; then
        clean_container "$container"
      fi
    fi
  done

  wait
  header_info
  echo -e "${COLOR_GREEN}${COLOR_BOLD} Concluído, containers selecionados foram limpos.${COLOR_RESET} \n"
}

# Função para deletar LXCs
# Permite ao usuário selecionar e deletar containers LXC
function delete_lxcs() {
  header_info
  echo "Carregando..."
  
  NODE=$(hostname)
  containers=$(pct list | tail -n +2 | awk '{print $0 " " $4}')

  if [ -z "$containers" ]; then
    whiptail --title "Exclusão de Container LXC" --msgbox "Nenhum container LXC disponível!" 10 60
    return 1
  fi

  menu_items=()
  FORMAT="%-10s %-15s %-10s"

  while read -r container; do
    container_id=$(echo $container | awk '{print $1}')
    container_name=$(echo $container | awk '{print $2}')
    container_status=$(echo $container | awk '{print $3}')
    formatted_line=$(printf "$FORMAT" "$container_name" "$container_status")
    menu_items+=("$container_id" "$formatted_line" "OFF")
  done <<<"$containers"

  CHOICES=$(whiptail --title "Exclusão de Container LXC" \
    --checklist "Selecione os containers LXC para excluir:" 25 60 13 \
    "${menu_items[@]}" 3>&2 2>&1 1>&3)

  if [ -z "$CHOICES" ]; then
    whiptail --title "Exclusão de Container LXC" \
      --msgbox "Nenhum container selecionado!" 10 60
    return 1
  fi

  read -p "Excluir containers manualmente ou automaticamente? (Padrão: manual) m/a: " DELETE_MODE
  DELETE_MODE=${DELETE_MODE:-m}

  selected_ids=$(echo "$CHOICES" | tr -d '"' | tr -s ' ' '\n')

  for container_id in $selected_ids; do
    status=$(pct status $container_id)

    if [ "$status" == "status: running" ]; then
      echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Parando container ${COLOR_BOLD}$container_id${COLOR_RESET}..."
      pct stop $container_id &
      sleep 5
      echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Container ${COLOR_BOLD}$container_id${COLOR_RESET} parado."
    fi

    if [[ "$DELETE_MODE" == "a" ]]; then
      echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Excluindo automaticamente o container ${COLOR_BOLD}$container_id${COLOR_RESET}..."
      pct destroy "$container_id" -f
      [ $? -eq 0 ] && echo "Container $container_id excluído." || whiptail --title "Erro" --msgbox "Falha ao excluir o container $container_id." 10 60
    else
      read -p "Excluir container $container_id? (s/N): " CONFIRM
      if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
        echo -e "${COLOR_TEAL}[Info]${COLOR_GREEN} Excluindo container ${COLOR_BOLD}$container_id${COLOR_RESET}..."
        pct destroy "$container_id" -f
        [ $? -eq 0 ] && echo "Container $container_id excluído." || whiptail --title "Erro" --msgbox "Falha ao excluir o container $container_id." 10 60
      fi
    fi
  done

  echo -e "\nProcesso de exclusão concluído."
}

# Função para limpar kernels antigos
# Permite ao usuário selecionar e remover kernels antigos do sistema
function clean_kernels() {
  # Usando as cores definidas no início do script

  # Detecta o kernel atual
  current_kernel=$(uname -r)
  available_kernels=$(dpkg --list | grep 'kernel-.*-pve' | awk '{print $2}' | grep -v "$current_kernel" | sort -V)

  header_info

  if [ -z "$available_kernels" ]; then
    echo -e "${COLOR_GREEN}${COLOR_BOLD}Nenhum kernel antigo detectado. Kernel atual: ${current_kernel}${COLOR_RESET}"
    return 0
  fi

  echo -e "${COLOR_MOSS}Kernels disponíveis para remoção:${COLOR_RESET}"
  echo "$available_kernels" | nl -w 2 -s '. '

  echo -e "\n${COLOR_MOSS}Selecione os kernels para remover (separados por vírgula, ex: 1,2):${COLOR_RESET}"
  read -r selected

  # Analisa a seleção
  IFS=',' read -r -a selected_indices <<<"$selected"
  kernels_to_remove=()

  for index in "${selected_indices[@]}"; do
    kernel=$(echo "$available_kernels" | sed -n "${index}p")
    if [ -n "$kernel" ]; then
      kernels_to_remove+=("$kernel")
    fi
  done

  if [ ${#kernels_to_remove[@]} -eq 0 ]; then
    echo -e "${COLOR_NAVY}Nenhuma seleção válida feita. Saindo.${COLOR_RESET}"
    return 1
  fi

  # Confirma a remoção
  echo -e "${COLOR_MOSS}Kernels a serem removidos:${COLOR_RESET}"
  printf "%s\n" "${kernels_to_remove[@]}"
  read -rp "Prosseguir com a remoção? (s/n): " confirm
  if [[ "$confirm" != "s" ]]; then
    echo -e "${COLOR_NAVY}Abortado.${COLOR_RESET}"
    return 1
  fi

  # Remove os kernels
  for kernel in "${kernels_to_remove[@]}"; do
    echo -e "${COLOR_MOSS}Removendo $kernel...${COLOR_RESET}"
    if apt-get purge -y "$kernel" >/dev/null 2>&1; then
      echo -e "${COLOR_GREEN}${COLOR_BOLD}Removido com sucesso: $kernel${COLOR_RESET}"
    else
      echo -e "${COLOR_NAVY}Falha ao remover: $kernel. Verifique as dependências.${COLOR_RESET}"
    fi
  done

  # Limpa e atualiza o GRUB
  echo -e "${COLOR_MOSS}Limpando...${COLOR_RESET}"
  apt-get autoremove -y >/dev/null 2>&1 && update-grub >/dev/null 2>&1
  echo -e "${COLOR_GREEN}${COLOR_BOLD}Limpeza e atualização do GRUB concluídas.${COLOR_RESET}"
}

# Função para criar template LXC
# Permite ao usuário selecionar e criar um template LXC
function create_template() {
  header_info
  echo "Carregando..."
  pveam update >/dev/null 2>&1
  TEMPLATE_MENU=()
  MSG_MAX_LENGTH=0
  while read -r TAG ITEM; do
    OFFSET=2
    ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
    TEMPLATE_MENU+=("$ITEM" "$TAG " "OFF")
  done < <(pveam available)
  TEMPLATE=$(whiptail --backtitle "Gerenciador Proxmox" --title "Todos os Templates LXC" --radiolist "\nSelecione um Template LXC para criar:\n" 16 $((MSG_MAX_LENGTH + 58)) 10 "${TEMPLATE_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"')
  [ -z "$TEMPLATE" ] && {
    whiptail --backtitle "Gerenciador Proxmox" --title "Nenhum Template LXC Selecionado" --msgbox "Parece que nenhum Template LXC foi selecionado" 10 68
    echo "Concluído"
    return
  }

  # Configuração do ambiente do script
  NAME=$(echo "$TEMPLATE" | grep -oE '^[^-]+-[^-]+')
  PASS="$(openssl rand -base64 8)"
  CTID=$(pvesh get /cluster/nextid)
  PCT_OPTIONS="
    -features keyctl=1,nesting=1
    -hostname $NAME
    -tags proxmox-helper-scripts
    -onboot 0
    -cores 2
    -memory 2048
    -password $PASS
    -net0 name=eth0,bridge=vmbr0,ip=dhcp
    -unprivileged 1
  "
  DEFAULT_PCT_OPTIONS=(
    -arch $(dpkg --print-architecture)
  )

  # Seleciona o armazenamento para o template
  STORAGE_LIST=($(pvesm status -content rootdir | awk 'NR>1 {print $1}'))
  if [ ${#STORAGE_LIST[@]} -eq 0 ]; then
    echo "Nenhum armazenamento válido encontrado. Saindo."
    return 1
  fi

  if [ ${#STORAGE_LIST[@]} -eq 1 ]; then
    STORAGE=${STORAGE_LIST[0]}
  else
    STORAGE=$(whiptail --backtitle "Gerenciador Proxmox" --title "Armazenamento" --menu "Selecione o armazenamento para o template:" 16 58 8 $(for s in "${STORAGE_LIST[@]}"; do echo "$s 'Armazenamento'"; done) 3>&1 1>&2 2>&3)
  fi

  if [ -z "$STORAGE" ]; then
    echo "Nenhum armazenamento selecionado. Saindo."
    return 1
  fi

  # Baixa e cria o template
  echo "Baixando o template $TEMPLATE..."
  pveam download local $TEMPLATE

  echo "Criando o container LXC $CTID..."
  pct create $CTID local:vztmpl/$TEMPLATE $PCT_OPTIONS "${DEFAULT_PCT_OPTIONS[@]}" -storage $STORAGE

  echo "Template LXC criado com sucesso!"
  echo "ID: $CTID"
  echo "Nome: $NAME"
  echo "Senha: $PASS"
}

# Função para configuração pós-instalação do Proxmox
# Configura repositórios e outras opções pós-instalação
function post_install() {
  header_info
  # Usando as cores definidas no início do script

  CHOICE=$(whiptail --backtitle "Gerenciador Proxmox" --title "FONTES" --menu "O gerenciador de pacotes usará as fontes corretas para atualizar e instalar pacotes no seu servidor Proxmox VE.\n \nCorrigir fontes do Proxmox VE?" 14 58 2 \
    "sim" " " \
    "não" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  sim)
    echo -e "${COLOR_MOSS}Corrigindo fontes do Proxmox VE...${COLOR_RESET}"
    cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
    echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' >/etc/apt/apt.conf.d/no-bookworm-firmware.conf
    echo -e "${COLOR_GREEN}${COLOR_BOLD}Fontes do Proxmox VE corrigidas.${COLOR_RESET}"
    ;;
  não)
    echo -e "${COLOR_NAVY}Selecionou não para corrigir fontes do Proxmox VE${COLOR_RESET}"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Gerenciador Proxmox" --title "PVE-ENTERPRISE" --menu "O repositório 'pve-enterprise' está disponível apenas para usuários que adquiriram uma assinatura do Proxmox VE.\n \nDesativar repositório 'pve-enterprise'?" 14 58 2 \
    "sim" " " \
    "não" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  sim)
    echo -e "${COLOR_MOSS}Desativando repositório 'pve-enterprise'${COLOR_RESET}"
    cat <<EOF >/etc/apt/sources.list.d/pve-enterprise.list
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
    echo -e "${COLOR_GREEN}${COLOR_BOLD}Repositório 'pve-enterprise' desativado${COLOR_RESET}"
    ;;
  não)
    echo -e "${COLOR_NAVY}Selecionou não para desativar repositório 'pve-enterprise'${COLOR_RESET}"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Gerenciador Proxmox" --title "PVE-NO-SUBSCRIPTION" --menu "O repositório 'pve-no-subscription' fornece acesso a todos os componentes de código aberto do Proxmox VE.\n \nAtivar repositório 'pve-no-subscription'?" 14 58 2 \
    "sim" " " \
    "não" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  sim)
    echo -e "${COLOR_MOSS}Ativando repositório 'pve-no-subscription'${COLOR_RESET}"
    cat <<EOF >/etc/apt/sources.list.d/pve-install-repo.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
    echo -e "${COLOR_GREEN}${COLOR_BOLD}Repositório 'pve-no-subscription' ativado${COLOR_RESET}"
    ;;
  não)
    echo -e "${COLOR_NAVY}Selecionou não para ativar repositório 'pve-no-subscription'${COLOR_RESET}"
    ;;
  esac

  CHOICE=$(whiptail --backtitle "Gerenciador Proxmox" --title "ATUALIZAR SISTEMA" --menu "Atualizar todos os pacotes do sistema?" 10 58 2 \
    "sim" " " \
    "não" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  sim)
    echo -e "${COLOR_MOSS}Atualizando pacotes do sistema...${COLOR_RESET}"
    apt-get update
    apt-get -y dist-upgrade
    echo -e "${COLOR_GREEN}${COLOR_BOLD}Sistema atualizado.${COLOR_RESET}"
    ;;
  não)
    echo -e "${COLOR_NAVY}Selecionou não para atualizar o sistema${COLOR_RESET}"
    ;;
  esac

  echo -e "\n${COLOR_GREEN}${COLOR_BOLD}Configuração pós-instalação concluída.${COLOR_RESET}\n"
}

# Menu principal
# Loop infinito que exibe o menu principal até que o usuário escolha sair
while true; do
  # Exibe o cabeçalho
  header_info
  # Cria um menu interativo com whiptail e armazena a opção selecionada
  # O menu tem 9 opções numeradas de 1 a 8
  # Configuração de cores para o whiptail, usando as cores da paleta definida
  export NEWT_COLORS="root=,${COLOR_NAVY#\033[} \
                     title=${COLOR_WHITE#\033[},${COLOR_DARK_GREEN#\033[} \
                     border=${COLOR_DARK_GREEN#\033[},${COLOR_DARK_GREEN#\033[} \
                     window=${COLOR_WHITE#\033[},${COLOR_TEAL#\033[} \
                     shadow=,${COLOR_NAVY#\033[} \
                     button=${COLOR_WHITE#\033[},${COLOR_GREEN#\033[} \
                     actbutton=${COLOR_WHITE#\033[},${COLOR_MOSS#\033[} \
                     checkbox=${COLOR_MOSS#\033[},${COLOR_WHITE#\033[} \
                     actcheckbox=${COLOR_GREEN#\033[},${COLOR_WHITE#\033[} \
                     entry=${COLOR_WHITE#\033[},${COLOR_TEAL#\033[} \
                     label=${COLOR_MOSS#\033[},${COLOR_WHITE#\033[} \
                     listbox=${COLOR_WHITE#\033[},${COLOR_TEAL#\033[} \
                     actlistbox=${COLOR_WHITE#\033[},${COLOR_GREEN#\033[} \
                     sellistbox=${COLOR_WHITE#\033[},${COLOR_MOSS#\033[}"
  # Menu principal com layout melhorado e mais espaço para as opções
  OPTION=$(whiptail --backtitle "Gerenciador Proxmox" --title "Menu Principal" --menu "\nSelecione uma opção:\n" 20 70 9 \
    "1" "Backup do Host" \
    "2" "Atualizar Repositórios" \
    "3" "Limpar LXCs" \
    "4" "Deletar LXCs" \
    "5" "Limpar Kernels" \
    "6" "Criar Template LXC" \
    "7" "Configurar Pós-instalação" \
    "8" "Sair" 3>&1 1>&2 2>&3)

  # Processa a opção selecionada pelo usuário
  case $OPTION in
    # Opção 1: Backup do Host
    1)
      # Loop que continua até o usuário escolher não fazer mais backups
      while true; do
        # Exibe uma caixa de diálogo de confirmação
        if (whiptail --backtitle "Gerenciador Proxmox" --title "Backup do Host Proxmox" --yesno "Isso criará backups de arquivos e diretórios específicos. Continuar?" 10 88); then
          # Se o usuário confirmar, chama a função de backup
          host_backup
        else
          # Se o usuário cancelar, sai do loop
          break
        fi
      done
      ;;
    # Opção 2: Atualizar Repositórios
    2)
      # Exibe uma caixa de diálogo de confirmação
      if (whiptail --backtitle "Gerenciador Proxmox" --title "Atualizar Repositórios" --yesno "Isso atualizará os repositórios em todos os containers. Continuar?" 10 88); then
        # Se o usuário confirmar, exibe o cabeçalho e chama a função de atualização
        header_info
        update_repo
        # Aguarda o usuário pressionar ENTER para continuar
        read -p "Pressione ENTER para continuar..."
      fi
      ;;
    # Opção 3: Limpar LXCs
    3)
      # Exibe uma caixa de diálogo de confirmação
      if (whiptail --backtitle "Gerenciador Proxmox" --title "Limpar LXCs" --yesno "Isso irá limpar logs, cache e atualizar listas apt nos containers LXC selecionados. Continuar?" 10 88); then
        # Se o usuário confirmar, exibe o cabeçalho e executa a função de limpeza
        header_info
        clean_lxcs
        # Aguarda o usuário pressionar ENTER para continuar
        read -p "Pressione ENTER para continuar..."
      fi
      ;;
    # Opção 4: Deletar LXCs
    4)
      # Exibe uma caixa de diálogo de confirmação
      if (whiptail --backtitle "Gerenciador Proxmox" --title "Deletar LXCs" --yesno "Isso irá deletar containers LXC selecionados. Continuar?" 10 88); then
        # Se o usuário confirmar, exibe o cabeçalho e executa a função de exclusão
        header_info
        delete_lxcs
        # Aguarda o usuário pressionar ENTER para continuar
        read -p "Pressione ENTER para continuar..."
      fi
      ;;
    # Opção 5: Limpar Kernels
    5)
      # Exibe uma caixa de diálogo de confirmação
      if (whiptail --backtitle "Gerenciador Proxmox" --title "Limpar Kernels" --yesno "Isso irá remover kernels antigos do sistema. Continuar?" 10 88); then
        # Se o usuário confirmar, exibe o cabeçalho e executa a função de limpeza de kernels
        header_info
        clean_kernels
        # Aguarda o usuário pressionar ENTER para continuar
        read -p "Pressione ENTER para continuar..."
      fi
      ;;
    # Opção 6: Criar Template LXC
    6)
      # Exibe uma caixa de diálogo de confirmação
      if (whiptail --backtitle "Gerenciador Proxmox" --title "Criar Template LXC" --yesno "Isso irá criar um novo template LXC. Continuar?" 10 88); then
        # Se o usuário confirmar, exibe o cabeçalho e executa a função de criação de templates
        header_info
        create_template
        # Aguarda o usuário pressionar ENTER para continuar
        read -p "Pressione ENTER para continuar..."
      fi
      ;;
    # Opção 7: Configurar Pós-instalação
    7)
      # Exibe uma caixa de diálogo de confirmação
      if (whiptail --backtitle "Gerenciador Proxmox" --title "Configurar Pós-instalação" --yesno "Isso irá executar as configurações pós-instalação do Proxmox. Continuar?" 10 88); then
        # Se o usuário confirmar, exibe o cabeçalho e executa a função de pós-instalação
        header_info
        post_install
        # Aguarda o usuário pressionar ENTER para continuar
        read -p "Pressione ENTER para continuar..."
      fi
      ;;
    # Opção 8: Sair do programa
    8)
      # Exibe o cabeçalho e uma mensagem de saída
      header_info
      echo "Vlw, flw..."
      # Encerra o script com código de saída 0 (sucesso)
      exit 0
      ;;
  esac
done
