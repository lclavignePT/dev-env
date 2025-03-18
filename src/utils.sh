#!/bin/bash
# docker-dev/src/utils.sh
# Funções utilitárias para o ambiente de desenvolvimento Docker

# Importar configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Importar configurações
if [ -f "$SCRIPT_DIR/config.sh" ]; then
  source "$SCRIPT_DIR/config.sh"
else
  echo "Erro: Não foi possível encontrar config.sh"
  exit 1
fi

# Função para logar mensagens
log_message() {
  local message="$1"
  local level="${2:-INFO}"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  if [ "$ENABLE_LOGGING" = true ]; then
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  fi
  
  # Também mostrar na saída padrão
  echo "[$level] $message"
}

# Função para verificar dependências
check_dependencies() {
  local missing_deps=()
  
  # Verificar Docker
  if ! command -v docker &> /dev/null; then
    missing_deps+=("docker")
  fi
  
  # Verificar Docker Compose
  if ! command -v docker compose &> /dev/null; then
    missing_deps+=("docker compose")
  fi
  
  # Se houver dependências faltando, mostrar erro
  if [ ${#missing_deps[@]} -gt 0 ]; then
    log_message "Dependências faltando: ${missing_deps[*]}" "ERROR"
    echo "Por favor, instale as dependências necessárias e tente novamente."
    return 1
  fi
  
  return 0
}

# Função para verificar se um diretório existe, criando-o se necessário
ensure_directory_exists() {
  local dir="$1"
  
  if [ ! -d "$dir" ]; then
    log_message "Criando diretório: $dir" "INFO"
    # Usando apenas mkdir -p para o diretório específico, sem copiar outros arquivos
    mkdir -p "$dir"
    
    # Verificar se é um diretório de projeto dentro da pasta projetos
    if [[ "$dir" == "$PROJECTS_DIR/"* ]]; then
      # Não criar subdiretórios vazios desnecessários (bin, src, docs, etc.)
      # que podem ser confundidos com projetos reais
      log_message "Diretório de projeto criado: $dir" "INFO"
    fi
  fi
}

# Função para obter o tipo de um projeto existente
get_project_type() {
  local project_dir="$1"
  local project_type="$DEFAULT_PROJECT_TYPE"
  
  # Verificar se o arquivo docker-compose.yml existe
  if [ -f "$project_dir/docker-compose.yml" ]; then
    # Determinar o tipo do projeto com base na imagem usada
    local image_type=$(grep "image:" "$project_dir/docker-compose.yml" | awk '{print $2}')
    case "$image_type" in
      *python*)
        project_type="python"
        ;;
      *node*)
        project_type="node"
        ;;
    esac
  fi
  
  echo "$project_type"
}

# Função para mostrar o tempo de execução
show_execution_time() {
  local start_time="$1"
  local end_time=$(date +%s)
  local execution_time=$((end_time - start_time))
  
  log_message "Tempo de execução: ${execution_time}s" "INFO"
} 