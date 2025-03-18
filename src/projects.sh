#!/bin/bash
# docker-dev/src/projects.sh
# Funções para gerenciamento de projetos

# Importar configurações e utilitários
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/images.sh"

# Constantes
METADATA_FILE=".dev-env"
CURRENT_VERSION="1.0.0"

# Funções para gerenciamento de metadados
create_project_metadata() {
  local project_dir="$1"
  local project_type="$2"
  local metadata_file="$project_dir/$METADATA_FILE"
  
  # Criar arquivo de metadados com informações básicas
  echo "TYPE=$project_type" > "$metadata_file"
  echo "CREATED=$(date -Iseconds)" >> "$metadata_file"
  echo "VERSION=$CURRENT_VERSION" >> "$metadata_file"
  
  # Ocultar o arquivo em sistemas Unix
  chmod 600 "$metadata_file"
}

get_metadata_value() {
  local project_dir="$1"
  local key="$2"
  local metadata_file="$project_dir/$METADATA_FILE"
  
  if [ -f "$metadata_file" ]; then
    grep "^$key=" "$metadata_file" | cut -d= -f2
  fi
}

is_dev_env_project() {
  local project_dir="$1"
  local metadata_file="$project_dir/$METADATA_FILE"
  
  [ -f "$metadata_file" ]
}

update_metadata_value() {
  local project_dir="$1"
  local key="$2"
  local value="$3"
  local metadata_file="$project_dir/$METADATA_FILE"
  
  if [ -f "$metadata_file" ]; then
    # Se a chave já existe, atualiza o valor
    if grep -q "^$key=" "$metadata_file"; then
      sed -i "s/^$key=.*/$key=$value/" "$metadata_file"
    else
      # Caso contrário, adiciona a nova chave
      echo "$key=$value" >> "$metadata_file"
    fi
  fi
}

# Criar um novo projeto
create_project() {
  local start_time=$(date +%s)
  local project_name="$1"
  local project_type="${2:-$DEFAULT_PROJECT_TYPE}"
  
  # Primeiro, limpar diretórios vazios desnecessários
  clean_empty_directories
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não especificado" "ERROR"
    return 1
  fi
  
  # Validar tipo de projeto
  case "$project_type" in
    base|python|node)
      # Tipo válido
      ;;
    *)
      log_message "Tipo de projeto inválido: $project_type" "ERROR"
      log_message "Tipos válidos: base, python, node" "INFO"
      return 1
      ;;
  esac
  
  local project_dir="$PROJECTS_DIR/$project_name"
  
  # Verificar se o projeto já existe
  if [ -d "$project_dir" ]; then
    log_message "Projeto $project_name já existe em $project_dir" "WARNING"
    return 1
  fi
  
  # Verificar/construir imagem correspondente
  local image_name
  case "$project_type" in
    base)
      image_name="$BASE_IMAGE_NAME"
      if ! check_image_exists "$image_name"; then
        log_message "Imagem base não encontrada. Construindo..." "INFO"
        build_base_image
      fi
      ;;
    python)
      image_name="$PYTHON_IMAGE_NAME"
      if ! check_image_exists "$image_name"; then
        log_message "Imagem Python não encontrada. Construindo..." "INFO"
        build_python_image
      fi
      ;;
    node)
      image_name="$NODE_IMAGE_NAME"
      if ! check_image_exists "$image_name"; then
        log_message "Imagem Node não encontrada. Construindo..." "INFO"
        build_node_image
      fi
      ;;
  esac
  
  # Criar diretório do projeto
  ensure_directory_exists "$project_dir"
  log_message "Diretório do projeto criado em $project_dir" "INFO"
  
  # Garantir que o usuário tem permissões no diretório do projeto
  chmod 777 "$project_dir"
  
  # Usar template apropriado para o docker-compose.yml
  local template_file="$TEMPLATES_DIR/docker-compose.$project_type.yml"
  
  # Se não existir template específico, usar o template base
  if [ ! -f "$template_file" ]; then
    template_file="$TEMPLATES_DIR/docker-compose.base.yml"
    
    # Se nem o template base existir, criar um novo
    if [ ! -f "$template_file" ]; then
      log_message "Template não encontrado. Criando novo..." "WARNING"
      create_docker_compose_template "$project_type" "$template_file"
    fi
  fi
  
  # Copiar e ajustar o template para o projeto
  cp "$template_file" "$project_dir/docker-compose.yml"
  
  # Substituir variáveis no docker-compose.yml
  sed -i "s|image: .*|image: $image_name|g" "$project_dir/docker-compose.yml"
  
  # Ajustar volumes específicos por tipo de projeto
  if [[ "$project_type" == "python" ]]; then
    # Para projetos Python, ajustar o volume para python_venvs
    sed -i "s|node_modules:|python_venvs:|g" "$project_dir/docker-compose.yml"
    sed -i "s|- node_modules:|- python_venvs:|g" "$project_dir/docker-compose.yml"
    sed -i "s|/.node_modules|/.venvs|g" "$project_dir/docker-compose.yml"
  fi
  
  # Criar arquivo de metadados
  create_project_metadata "$project_dir" "$project_type"
  
  log_message "Ambiente para o projeto $project_name ($project_type) criado com sucesso!" "SUCCESS"
  log_message "Use 'dev-env enter $project_name' para acessar o ambiente" "INFO"
  
  show_execution_time "$start_time"
  return 0
}

# Entrar no shell de um projeto
enter_project() {
  local project_name="$1"
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não especificado" "ERROR"
    return 1
  fi
  
  local project_dir="$PROJECTS_DIR/$project_name"
  
  # Verificar se o projeto existe
  if [ ! -d "$project_dir" ]; then
    log_message "Projeto $project_name não existe" "ERROR"
    return 1
  fi
  
  # Verificar se é um projeto dev-env
  if ! is_dev_env_project "$project_dir"; then
    log_message "Diretório '$project_name' não é um projeto gerenciado pelo dev-env" "ERROR"
    log_message "Use 'dev-env create $project_name TIPO' para criar um novo projeto" "INFO"
    return 1
  fi
  
  # Entrar no diretório do projeto
  cd "$project_dir"
  
  # Verificar se o container está rodando
  local container_running=$(docker compose ps -q dev)
  if [ -z "$container_running" ]; then
    log_message "Iniciando ambiente de desenvolvimento para $project_name..." "INFO"
    docker compose up -d
  fi
  
  # Criar um alias no .zshrc do container para abrir o VS Code
  local container_id=$(docker compose ps -q dev)
  
  if [ -n "$container_id" ]; then
    # Configurar Git no container
    docker exec -u devuser "$container_id" bash -c "git config --global user.name \"Development User\" && git config --global user.email \"dev@localhost\" && git config --global --add safe.directory /home/devuser/project"
  fi
  
  log_message "Conectando ao shell do ambiente $project_name..." "INFO"
  docker compose exec -u devuser dev /bin/zsh
  
  return 0
}

# Reconstruir um projeto
rebuild_project() {
  local project_name="$1"
  local start_time=$(date +%s)
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não informado" "ERROR"
    return 1
  fi
  
  # Verificar se o projeto existe
  local project_dir="$PROJECTS_DIR/$project_name"
  if [ ! -d "$project_dir" ]; then
    log_message "Projeto $project_name não encontrado" "ERROR"
    return 1
  fi
  
  # Verificar se o docker-compose.yml existe
  if [ ! -f "$project_dir/docker-compose.yml" ]; then
    log_message "Arquivo docker-compose.yml não encontrado para o projeto $project_name" "ERROR"
    return 1
  fi
  
  # Parar e remover containers
  log_message "Parando e removendo containers do projeto $project_name..." "INFO"
  
  local workdir="$project_dir"
  
  # Executar o docker compose down
  cd "$workdir" || return 1
  docker compose down
  
  # Iniciar novamente
  log_message "Recriando containers do projeto $project_name..." "INFO"
  docker compose up -d
  
  # Verificar se o container está em execução
  if [ "$(docker compose ps -q)" = "" ]; then
    log_message "Erro ao iniciar o container para o projeto $project_name" "ERROR"
    return 1
  fi
  
  # Corrigir permissões após a reconstrução
  fix_project_permissions "$project_name"
  
  log_message "Ambiente para o projeto $project_name reconstruído com sucesso!" "SUCCESS"
  log_message "Use 'dev-env enter $project_name' para acessar o ambiente" "INFO"
  
  show_execution_time "$start_time"
  return 0
}

# Remover diretórios vazios desnecessários da pasta projetos
clean_empty_directories() {
  # Lista de diretórios que não devem existir vazios dentro de projetos
  local dirs_to_check=("bin" "docs" "installer" "src" "tests")
  
  for dir in "${dirs_to_check[@]}"; do
    local full_path="$PROJECTS_DIR/$dir"
    # Verificar se existe e está vazio
    if [ -d "$full_path" ] && [ -z "$(ls -A "$full_path" 2>/dev/null)" ]; then
      log_message "Removendo diretório vazio desnecessário: $full_path" "INFO"
      rmdir "$full_path" 2>/dev/null || true
    fi
  done
}

# Listar todos os projetos
list_projects() {
  # Primeiro limpar diretórios vazios desnecessários
  clean_empty_directories
  
  log_message "Listando ambientes de desenvolvimento disponíveis..." "INFO"
  echo "Ambientes de desenvolvimento disponíveis:"
  echo ""
  
  if [ ! -d "$PROJECTS_DIR" ]; then
    echo "Nenhum ambiente encontrado"
    return 0
  fi
  
  local found_projects=false
  
  for project in $(ls -d $PROJECTS_DIR/*/ 2>/dev/null); do
    local project_name=$(basename "$project")
    
    # Verificar se é um projeto dev-env
    if is_dev_env_project "$project"; then
      # Obter tipo do projeto dos metadados
      local project_type=$(get_metadata_value "$project" "TYPE")
      # Se não conseguir do metadata, tenta inferir
      if [ -z "$project_type" ]; then
        project_type=$(get_project_type "$project")
        # Atualizar o metadata já que conseguimos inferir o tipo
        update_metadata_value "$project" "TYPE" "$project_type"
      fi
      
      echo "  - $project_name ($project_type)"
      found_projects=true
    fi
  done
  
  if [ "$found_projects" = false ]; then
    echo "Nenhum ambiente encontrado"
  fi
  
  return 0
}

# Criar um template de docker-compose.yml
create_docker_compose_template() {
  local project_type="$1"
  local output_file="$2"
  local image_name
  local volume_name
  
  # Obter ID de usuário e grupo do usuário atual
  local user_id=$(id -u)
  local group_id=$(id -g)
  
  # Determinar imagem baseada no tipo do projeto
  case "$project_type" in
    python)
      image_name="$PYTHON_IMAGE_NAME"
      volume_name="python_venvs"
      ;;
    node)
      image_name="$NODE_IMAGE_NAME"
      volume_name="node_modules"
      ;;
    *)
      image_name="$BASE_IMAGE_NAME"
      volume_name="project_data"
      ;;
  esac
  
  # Criar diretório para o template se não existir
  ensure_directory_exists "$(dirname "$output_file")"
  
  # Criar arquivo de template
  cat > "$output_file" << EOL
services:
  dev:
    image: ${image_name}
    volumes:
      - .:/home/devuser/project
      - $HOME/.ssh:/home/devuser/.ssh:ro
      # - $HOME/.gitconfig:/home/devuser/.gitconfig:ro
      - ${volume_name}:/home/devuser/.${volume_name}
      # Suporte a X11 para aplicações gráficas
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /var/run/dbus:/var/run/dbus
      # Suporte a fontes
      - /usr/share/fonts:/usr/share/fonts:ro
      - $HOME/.local/share/fonts:/home/devuser/.local/share/fonts:ro
      # Suporte a temas do sistema
      - /usr/share/themes:/usr/share/themes:ro
      - /usr/share/icons:/usr/share/icons:ro
      - $HOME/.themes:/home/devuser/.themes:ro
      - $HOME/.icons:/home/devuser/.icons:ro
      # Certificados SSL/TLS
      - /etc/ssl/certs:/etc/ssl/certs:ro
    working_dir: /home/devuser/project
    command: /bin/zsh
    environment:
      - DISPLAY=\${DISPLAY}
      - XAUTHORITY=/home/devuser/.Xauthority
      - LANG=\${LANG:-en_US.UTF-8}
      - EDITOR=\${EDITOR:-nano}
      - TERM=\${TERM:-xterm-256color}
    # Usar o mesmo ID de usuário e grupo do host para evitar problemas de permissão
    user: "${user_id}:${group_id}"
    tty: true
    stdin_open: true
    network_mode: host
    # Adicionar capacidades para melhor integração com o host
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
volumes:
  ${volume_name}:
EOL
  
  log_message "Template para $project_type criado em $output_file" "INFO"
  return 0
}

# Limpar o projeto (remover volumes)
clean_project() {
  local project_name="$1"
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não especificado" "ERROR"
    return 1
  fi
  
  local project_dir="$PROJECTS_DIR/$project_name"
  
  # Verificar se o projeto existe
  if [ ! -d "$project_dir" ]; then
    log_message "Projeto $project_name não existe" "ERROR"
    return 1
  fi
  
  # Verificar se é um projeto dev-env
  if ! is_dev_env_project "$project_dir"; then
    log_message "Diretório '$project_name' não é um projeto gerenciado pelo dev-env" "ERROR"
    log_message "Use 'dev-env create $project_name TIPO' para criar um novo projeto" "INFO"
    return 1
  fi
  
  # Mudar para o diretório do projeto
  cd "$project_dir"
  
  # Verificar se o arquivo docker-compose.yml existe
  if [ ! -f "docker-compose.yml" ]; then
    log_message "Arquivo docker-compose.yml não encontrado no projeto" "ERROR"
    return 1
  fi
  
  # Método 1: Usar docker compose down -v para remover todos os volumes associados
  log_message "Parando containers e removendo volumes do projeto $project_name..." "INFO"
  if docker compose down -v; then
    log_message "Containers e volumes removidos com sucesso" "SUCCESS"
  else
    log_message "Erro ao parar containers ou remover volumes" "ERROR"
    return 1
  fi
  
  # Método 2: Identificar e remover volumes individualmente (backup)
  log_message "Verificando se há volumes residuais..." "INFO"
  local volumes=$(docker volume ls -q --filter "name=${project_name}_")
  
  if [ -n "$volumes" ]; then
    log_message "Removendo volumes residuais..." "INFO"
    echo "$volumes" | xargs -r docker volume rm
    
    # Verificar se ainda existem volumes
    volumes=$(docker volume ls -q --filter "name=${project_name}_")
    if [ -n "$volumes" ]; then
      log_message "Alguns volumes não puderam ser removidos. Eles podem estar em uso por outros containers." "WARNING"
    else
      log_message "Todos os volumes residuais foram removidos" "SUCCESS"
    fi
  fi
  
 # Método 3: Limpar diretório node_modules local se existir
  if [ -d "node_modules" ]; then
    log_message "Removendo diretório node_modules local..." "INFO"
    
    # Tentar remover normalmente primeiro
    if ! rm -rf node_modules 2>/dev/null; then
      # Se falhar, tentar com sudo
      log_message "Permissão negada. Tentando remover com sudo..." "WARNING"
      if command -v sudo >/dev/null 2>&1; then
        if sudo rm -rf node_modules; then
          log_message "Diretório node_modules removido com sudo" "SUCCESS"
        else
          log_message "Falha ao remover node_modules mesmo com sudo" "ERROR"
        fi
      else
        log_message "Sudo não disponível. Não foi possível remover node_modules" "ERROR"
        log_message "Você pode remover manualmente com: sudo rm -rf \"$project_dir/node_modules\"" "INFO"
      fi
    else
      log_message "Diretório node_modules removido" "SUCCESS"
    fi
  fi
  
  # Registrar limpeza nos metadados
  update_metadata_value "$project_dir" "CLEANED" "$(date -Iseconds)"
  
  log_message "Limpeza concluída. O ambiente será recriado na próxima execução" "SUCCESS"
  log_message "Para iniciar o projeto, use: dev-env enter $project_name" "INFO"
  
  return 0
}

# Abrir o VS Code para um projeto
open_vscode() {
  local project_name="$1"
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não especificado" "ERROR"
    return 1
  fi
  
  local project_dir="$PROJECTS_DIR/$project_name"
  
  # Verificar se o projeto existe
  if [ ! -d "$project_dir" ]; then
    log_message "Projeto $project_name não existe" "ERROR"
    return 1
  fi
  
  # Verificar se é um projeto dev-env
  if ! is_dev_env_project "$project_dir"; then
    log_message "Diretório '$project_name' não é um projeto gerenciado pelo dev-env" "ERROR"
    log_message "Use 'dev-env create $project_name TIPO' para criar um novo projeto" "INFO"
    return 1
  fi
  
  log_message "A funcionalidade de integração com VS Code foi desativada" "INFO"
  
  return 0
}

# Entrar no shell de um projeto
enter_project_shell() {
  local project_name="$1"
  local start_time=$(date +%s)
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não informado" "ERROR"
    return 1
  fi
  
  # Verificar se o projeto existe
  local project_dir="$PROJECTS_DIR/$project_name"
  if [ ! -d "$project_dir" ]; then
    log_message "Projeto $project_name não encontrado" "ERROR"
    return 1
  fi
  
  # Verificar se o docker-compose.yml existe
  if [ ! -f "$project_dir/docker-compose.yml" ]; then
    log_message "Arquivo docker-compose.yml não encontrado para o projeto $project_name" "ERROR"
    return 1
  fi
  
  # Iniciar o container
  log_message "Iniciando o container do projeto $project_name..." "INFO"
  
  local workdir="$project_dir"
  
  # Executar o docker compose up
  cd "$workdir" || return 1
  docker compose up -d
  
  # Verificar se o container está em execução
  if [ "$(docker compose ps -q)" = "" ]; then
    log_message "Erro ao iniciar o container para o projeto $project_name" "ERROR"
    return 1
  fi
  
  # Corrigir permissões se necessário
  fix_project_permissions "$project_name"
  
  log_message "Conectando ao shell do ambiente para $project_name" "INFO"
  log_message "Para abrir o VS Code, digite 'code' no terminal do container" "INFO"
  
  # Conectar ao shell
  docker compose exec dev /bin/zsh || {
    log_message "Erro ao conectar ao shell do container" "ERROR"
    return 1
  }
  
  show_execution_time "$start_time"
  return 0
}

# Função para corrigir permissões do projeto
fix_project_permissions() {
  local project_name="$1"
  
  if [ -z "$project_name" ]; then
    log_message "Nome do projeto não informado para corrigir permissões" "ERROR"
    return 1
  fi
  
  local project_dir="$PROJECTS_DIR/$project_name"
  
  log_message "Verificando e corrigindo permissões para $project_name..." "INFO"
  
  # Obter o ID de usuário e grupo do container
  local container_name="${project_name}-dev-1"
  local container_uid=$(docker compose -f "$project_dir/docker-compose.yml" exec -T dev id -u 2>/dev/null)
  local container_gid=$(docker compose -f "$project_dir/docker-compose.yml" exec -T dev id -g 2>/dev/null)
  
  if [ -n "$container_uid" ] && [ -n "$container_gid" ]; then
    log_message "Ajustando permissões para UID:GID = $container_uid:$container_gid" "INFO"
    
    # Verificar permissões do arquivo .dev-env
    if [ -f "$project_dir/.dev-env" ]; then
      if [ "$(stat -c "%u:%g" "$project_dir/.dev-env")" != "$container_uid:$container_gid" ]; then
        sudo chown "$container_uid:$container_gid" "$project_dir/.dev-env"
        log_message "Permissões de .dev-env atualizadas" "INFO"
      fi
    fi
    
    # Garantir que o diretório .venvs tenha as permissões corretas
    if [ -d "$project_dir/.venvs" ]; then
      sudo chown -R "$container_uid:$container_gid" "$project_dir/.venvs"
      log_message "Permissões de .venvs atualizadas" "INFO"
    fi
    
    # Verificar o diretório .git
    if [ -d "$project_dir/.git" ]; then
      sudo chown -R "$container_uid:$container_gid" "$project_dir/.git"
      log_message "Permissões de .git atualizadas" "INFO"
    fi
    
    # Verificar o arquivo docker-compose.yml
    if [ -f "$project_dir/docker-compose.yml" ]; then
      sudo chown "$container_uid:$container_gid" "$project_dir/docker-compose.yml"
      log_message "Permissões de docker-compose.yml atualizadas" "INFO"
    fi
  else
    log_message "Não foi possível obter UID/GID do container" "WARNING"
  fi
  
  return 0
} 