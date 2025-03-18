#!/bin/bash
# docker-dev/installer/install.sh
# Script de instalação para o ambiente de desenvolvimento Docker

set -e

# Obter o diretório do script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$HOME/.config/dev-env"
CONFIG_FILE="$CONFIG_DIR/config"

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Função para imprimir mensagens de informação
info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

# Função para imprimir avisos
warning() {
  echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Função para imprimir erros
error() {
  echo -e "${RED}[ERRO]${NC} $1"
}

# Verificar se o Docker está instalado
check_docker() {
  if ! command -v docker &> /dev/null; then
    error "Docker não está instalado."
    echo "Por favor, instale o Docker antes de continuar:"
    echo "https://docs.docker.com/engine/install/"
    return 1
  fi
  
  # Verificar se o usuário pode executar Docker sem sudo
  if ! docker info &> /dev/null; then
    warning "Você pode precisar adicionar seu usuário ao grupo 'docker':"
    echo "sudo usermod -aG docker $USER"
    echo "Em seguida, faça logout e login novamente, ou execute: newgrp docker"
  fi
  
  return 0
}

# Copiar arquivos para os destinos
copy_files() {
  info "Copiando arquivos..."
  
  # Copiar arquivos de script
  cp -r "$PROJECT_DIR/bin/"* "$HOME/.local/share/dev-env/bin/"
  cp -r "$PROJECT_DIR/src/"* "$HOME/.local/share/dev-env/src/"
  
  # Tornar scripts executáveis
  chmod +x "$HOME/.local/share/dev-env/bin/dev-env"
  
  info "Arquivos copiados com sucesso."
}

# Adicionar ao PATH do usuário
add_to_path() {
  local BIN_DIR="$HOME/.local/share/dev-env/bin"
  local CURRENT_SHELL="$(basename "$SHELL")"
  
  echo ""
  echo "Qual(is) shell(s) você utiliza? Múltiplas opções são permitidas."
  echo "1) bash"
  echo "2) zsh"
  echo "3) ambos"
  echo "4) nenhum/outro (configuração manual)"
  echo -n "Escolha [1-4]: "
  read shell_choice
  
  case "$shell_choice" in
    1)
      update_shell_rc "$HOME/.bashrc" "$BIN_DIR"
      echo "Para ativar as alterações, execute: source $HOME/.bashrc"
      ;;
    2)
      update_shell_rc "$HOME/.zshrc" "$BIN_DIR"
      echo "Para ativar as alterações, execute: source $HOME/.zshrc"
      ;;
    3)
      update_shell_rc "$HOME/.bashrc" "$BIN_DIR"
      update_shell_rc "$HOME/.zshrc" "$BIN_DIR"
      echo "Para ativar as alterações, execute:"
      echo "  source $HOME/.bashrc # se estiver usando bash"
      echo "  source $HOME/.zshrc  # se estiver usando zsh"
      ;;
    4|*)
      info "Configuração manual necessária. Adicione ao seu arquivo RC de shell:"
      echo "export PATH=\"\$PATH:$BIN_DIR\""
      echo "alias dev-env=\"$BIN_DIR/dev-env\""
      ;;
  esac
}

# Função auxiliar para atualizar arquivos RC de shell
update_shell_rc() {
  local RC_FILE="$1"
  local BIN_DIR="$2"
  
  # Verificar se o arquivo existe
  if [ ! -f "$RC_FILE" ]; then
    touch "$RC_FILE"
  fi
  
  # Verificar se já está no PATH
  if grep -q ".local/share/dev-env/bin" "$RC_FILE" || grep -q "dev-env/bin" "$RC_FILE"; then
    info "As configurações já existem em $RC_FILE"
  else
    info "Adicionando configurações em $RC_FILE..."
    echo "" >> "$RC_FILE"
    echo "# Docker Dev Environment" >> "$RC_FILE"
    echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$RC_FILE"
    echo "alias dev-env=\"$BIN_DIR/dev-env\"" >> "$RC_FILE"
    info "Configurações adicionadas com sucesso em $RC_FILE"
  fi
}

# Construir imagens Docker
build_images() {
  info "Construindo imagens Docker..."
  
  if [ -x "$HOME/.local/share/dev-env/bin/dev-env" ]; then
    "$HOME/.local/share/dev-env/bin/dev-env" build-all
    info "Imagens construídas com sucesso."
  else
    error "O executável dev-env não foi encontrado ou não tem permissão de execução."
    error "Verifique a instalação e tente novamente."
    exit 1
  fi
}

# Função principal de instalação
main() {
  clear
  echo "==============================================="
  echo "  Instalador do Ambiente de Desenvolvimento Docker"
  echo "==============================================="
  echo ""
  echo "Este instalador irá configurar o ambiente dev-env,"
  echo "que permite criar e gerenciar ambientes de desenvolvimento"
  echo "isolados com Docker."
  echo ""
  
  # Perguntar direto sem mensagem prévia
  echo -n "Caminho do Workspace: "
  read projects_dir
  
  # Se vazio, usar o padrão
  if [ -z "$projects_dir" ]; then
    projects_dir="$HOME/dev-env-projects"
    echo "Usando caminho padrão: $projects_dir"
  else
    # Garantir que o caminho seja relativo ao $HOME
    # Se começar com /, mover para dentro de $HOME
    if [[ "$projects_dir" = /* ]]; then
      # Remover a barra inicial para evitar caminhos como /home/user//path
      projects_dir=${projects_dir#/}
      projects_dir="$HOME/$projects_dir"
      echo "Ajustando caminho para: $projects_dir"
    else
      # Se não começar com /, assumir que já é relativo ao $HOME
      projects_dir="$HOME/$projects_dir"
    fi
  fi
  
  # Expandir o caminho
  PROJECTS_DIR=$(eval echo "$projects_dir")
  
  # Verificar se temos permissão para criar o diretório
  if mkdir -p "$PROJECTS_DIR" 2>/dev/null; then
    info "Diretório de projetos criado/verificado com sucesso: $PROJECTS_DIR"
  else
    error "Não foi possível criar o diretório: $PROJECTS_DIR"
    error "Por favor, escolha um caminho diferente onde você tenha permissões de escrita."
    exit 1
  fi
  
  # Criar diretório de configuração e salvar
  mkdir -p "$CONFIG_DIR"
  echo "PROJECTS_DIR=$PROJECTS_DIR" > "$CONFIG_FILE"
  
  # Verificar Docker
  info "Verificando pré-requisitos Docker..."
  check_docker || exit 1
  
  # Criar diretórios do sistema
  info "Criando diretórios do sistema..."
  mkdir -p "$HOME/.local/share/dev-env/bin" "$HOME/.local/share/dev-env/src"
  
  # Copiar arquivos
  copy_files
  
  # Adicionar ao PATH
  add_to_path
  
  echo ""
  echo "==============================================="
  echo "  Instalação concluída com sucesso!"
  echo "==============================================="
  echo ""
  echo "Seu ambiente dev-env está configurado em:"
  echo "  - Sistema: $HOME/.local/share/dev-env"
  echo "  - Projetos: $PROJECTS_DIR"
  echo "  - Configuração: $CONFIG_DIR"
  echo ""
  echo "Deseja construir as imagens Docker agora? (S/n)"
  read response
  
  if [[ "$response" =~ ^([yY][eE][sS]|[yY]|[sS])$ ]] || [[ -z "$response" ]]; then
    build_images
  else
    info "Você pode construir as imagens mais tarde com: dev-env build-all"
  fi
}

# Executar o script
main 