#!/bin/bash
# docker-dev/src/images.sh
# Funções para gerenciamento de imagens Docker

# Importar configurações e utilitários
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"

# Construir a imagem base
build_base_image() {
  log_message "Construindo imagem base..." "INFO"
  
  # Caminho para o diretório base (em ambiente de desenvolvimento)
  BASE_DOCKERFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/base"
  
  # Debug: mostrar o caminho do Dockerfile
  echo "DEBUG: Usando Dockerfile em $BASE_DOCKERFILE_DIR/Dockerfile"
  echo "DEBUG: Diretório atual: $(pwd)"
  echo "DEBUG: Verificando se o arquivo existe: $(ls -la $BASE_DOCKERFILE_DIR/Dockerfile 2>/dev/null || echo 'Arquivo não encontrado')"
  
  # Construir a imagem base
  docker build -t "$BASE_IMAGE_NAME" -f "$BASE_DOCKERFILE_DIR/Dockerfile" "$BASE_DOCKERFILE_DIR"
  
  if [ $? -eq 0 ]; then
    log_message "Imagem base construída com sucesso!" "SUCCESS"
    return 0
  else
    log_message "Falha ao construir imagem base" "ERROR"
    return 1
  fi
}

# Construir imagem Python
build_python_image() {
  log_message "Construindo imagem Python..." "INFO"
  
  # Verificar se a imagem base existe
  if [[ "$(docker images -q $BASE_IMAGE_NAME 2> /dev/null)" == "" ]]; then
    log_message "Imagem base não encontrada. Construindo primeiro..." "WARNING"
    build_base_image
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
  
  # Caminho para o diretório base (em ambiente de desenvolvimento)
  BASE_DOCKERFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/base"
  
  # Debug: mostrar o caminho do Dockerfile.python
  echo "DEBUG: Usando Dockerfile em $BASE_DOCKERFILE_DIR/Dockerfile.python"
  echo "DEBUG: Verificando se o arquivo existe: $(ls -la $BASE_DOCKERFILE_DIR/Dockerfile.python 2>/dev/null || echo 'Arquivo não encontrado')"
  
  # Construir imagem Python
  docker build -t "$PYTHON_IMAGE_NAME" -f "$BASE_DOCKERFILE_DIR/Dockerfile.python" "$BASE_DOCKERFILE_DIR"
  
  if [ $? -eq 0 ]; then
    log_message "Imagem Python construída com sucesso!" "SUCCESS"
    return 0
  else
    log_message "Falha ao construir imagem Python" "ERROR"
    return 1
  fi
}

# Construir imagem Node.js
build_node_image() {
  log_message "Construindo imagem Node.js..." "INFO"
  
  # Caminho para o diretório base (em ambiente de desenvolvimento)
  BASE_DOCKERFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/base"
  
  # Debug: mostrar o caminho do Dockerfile.node
  echo "DEBUG: Usando Dockerfile em $BASE_DOCKERFILE_DIR/Dockerfile.node"
  echo "DEBUG: Verificando se o arquivo existe: $(ls -la $BASE_DOCKERFILE_DIR/Dockerfile.node 2>/dev/null || echo 'Arquivo não encontrado')"
  
  # Construir a imagem Node diretamente usando FROM ubuntu
  docker build -t "$NODE_IMAGE_NAME" -f "$BASE_DOCKERFILE_DIR/Dockerfile.node" "$BASE_DOCKERFILE_DIR"
  
  if [ $? -eq 0 ]; then
    log_message "Imagem Node.js construída com sucesso!" "SUCCESS"
    return 0
  else
    log_message "Falha ao construir imagem Node.js" "ERROR"
    return 1
  fi
}

# Construir todas as imagens
build_all_images() {
  local start_time=$(date +%s)
  
  log_message "Construindo todas as imagens..." "INFO"
  
  # Construir imagem base
  build_base_image
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Construir imagem Python
  build_python_image
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Construir imagem Node
  build_node_image
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  log_message "Todas as imagens construídas com sucesso!" "SUCCESS"
  show_execution_time "$start_time"
  
  return 0
}

# Verificar se uma imagem existe
check_image_exists() {
  local image_name="$1"
  
  if [[ "$(docker images -q $image_name 2> /dev/null)" == "" ]]; then
    return 1  # Imagem não existe
  else
    return 0  # Imagem existe
  fi
} 