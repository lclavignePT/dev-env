#!/bin/bash
# docker-dev/src/config.sh
# Arquivo de configuração central para o ambiente de desenvolvimento Docker

# Diretório base para arquivos do sistema
export BASE_DIR="$HOME/.local/share/dev-env"

# Diretórios da estrutura do sistema
export BIN_DIR="$BASE_DIR/bin"
export SRC_DIR="$BASE_DIR/src"
export DOCKERFILES_DIR="$SRC_DIR/dockerfiles"
export TEMPLATES_DIR="$SRC_DIR/templates"
export DOCS_DIR="$BASE_DIR/docs"
export TESTS_DIR="$BASE_DIR/tests"

# Diretório para os projetos (definido pelo usuário durante a instalação)
if [ -z "$PROJECTS_DIR" ]; then
    echo "Erro: PROJECTS_DIR não está definido."
    echo "Por favor, execute o instalador novamente."
    exit 1
fi

# Configurações de imagens
export BASE_IMAGE_NAME="dev-base"
export PYTHON_IMAGE_NAME="dev-python"
export NODE_IMAGE_NAME="dev-node"

# Opções de configuração
export DEFAULT_PROJECT_TYPE="base"
export ENABLE_LOGGING=true
export LOG_FILE="$BASE_DIR/dev-env.log" 