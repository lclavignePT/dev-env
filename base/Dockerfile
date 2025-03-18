# docker-dev/base/Dockerfile
FROM ubuntu:24.04

# Evitar prompts interativos
ENV DEBIAN_FRONTEND=noninteractive

# Instalar pacotes essenciais
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    zsh \
    openssh-client \
    sudo \
    build-essential \
    vim \
    micro \
    htop \
    ripgrep \
    fd-find \
    locales \
    ca-certificates \
    gnupg \
    lsb-release \
    zip \
    unzip \
    jq \
    xauth \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*

# Configurar timezone para Portugal
RUN ln -fs /usr/share/zoneinfo/Europe/Lisbon /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Configurar localização para PT-PT
RUN locale-gen pt_PT.UTF-8
ENV LANG=pt_PT.UTF-8
ENV LANGUAGE=pt_PT:pt
ENV LC_ALL=pt_PT.UTF-8

# Instalar Docker CLI (para Docker-in-Docker se necessário)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Instalar GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    sudo apt update && \
    sudo apt install gh -y && \
    rm -rf /var/lib/apt/lists/*

# Configurar usuário não-root
ARG USERNAME=devuser
ARG USER_UID=1001  # Usando UID 1001 pois 1000 já existe na imagem base
ARG USER_GID=1001  # Usando GID 1001 pois 1000 já existe na imagem base

# Criar novo grupo e usuário
RUN sudo groupadd --gid $USER_GID $USERNAME && \
    sudo useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME

# Oh My ZSH e plugins
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    git config --global --add safe.directory '*' && \
    git config --global user.name "Development User" && \
    git config --global user.email "dev@localhost"

# Configurar .zshrc com plugins e aliases úteis
RUN echo 'export ZSH="$HOME/.oh-my-zsh"' > ~/.zshrc && \
    echo 'ZSH_THEME="half-life"' >> ~/.zshrc && \
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> ~/.zshrc && \
    echo 'source $ZSH/oh-my-zsh.sh' >> ~/.zshrc && \
    echo 'alias la="ls -la"' >> ~/.zshrc && \
    echo 'alias update="sudo apt update && sudo apt upgrade -y"' >> ~/.zshrc

# Criar diretório de projeto
RUN mkdir -p /home/$USERNAME/project
WORKDIR /home/$USERNAME/project

# Assegurar que o diretório de configuração para o Micro existe e tem as permissões corretas
RUN mkdir -p /home/$USERNAME/.config/micro && chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# Shell padrão
ENV SHELL=/bin/zsh
CMD ["zsh"]