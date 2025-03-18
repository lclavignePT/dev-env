# Docker Development Environment (dev-env)

Um sistema para criar e gerenciar ambientes de desenvolvimento isolados usando Docker.

## Visão Geral

Este projeto permite criar ambientes de desenvolvimento isolados para cada projeto, mantendo o sistema principal limpo e organizado. Cada ambiente é um contêiner Docker com todas as dependências necessárias.

## Características

- **Ambiente Base**: Contêiner Ubuntu com ferramentas essenciais de desenvolvimento
- **Ambientes Específicos**: Suporte para Python e Node.js
- **Isolamento de Projetos**: Cada projeto tem seu próprio ambiente
- **Compartilhamento de Configurações**: Compartilha SSH, Git e outras configurações com o host
- **Suporte a GUI**: Configurado para executar VS Code e outras ferramentas gráficas
- **Gerenciamento Fácil**: Interface de linha de comando simples para gerenciar ambientes
- **Limpeza de Volumes**: Função `clean` para limpar volumes Docker e diretórios node_modules
- **Metadados de Projeto**: Sistema de metadados para gerenciar informações do projeto
- **Suporte ao VS Code**: Integração com VS Code com o comando `code` no container

## Pré-requisitos

- Docker
- Docker Compose
- Linux (testado no Ubuntu)

## Instalação

```bash
# Extrair o arquivo
tar -xzf dev-env-YYYYMMDD.tar.gz
cd dev-env-YYYYMMDD

# Executar o instalador
./installer/install.sh
```

## Uso

Depois de instalar, você pode:

```bash
# Criar um novo ambiente para um projeto Python
dev-env create meu-app-python python

# Criar um novo ambiente para um projeto Node.js
dev-env create minha-webapp node

# Criar um ambiente base
dev-env create meu-projeto

# Entrar em um ambiente de projeto
dev-env enter meu-projeto

# Abrir VS Code para um projeto
dev-env code meu-projeto

# Limpar volumes e node_modules de um projeto
dev-env clean meu-projeto

# Listar todos os ambientes
dev-env list

# Reconstruir um ambiente
dev-env rebuild meu-projeto
```

## Usando VS Code

Existem duas maneiras de usar o VS Code com seus projetos:

1. Do host: Execute `dev-env code nome-do-projeto`
2. De dentro do container: Entre no container com `dev-env enter nome-do-projeto` e depois execute `code` 

## Licença

Este projeto é licenciado sob a licença MIT.
