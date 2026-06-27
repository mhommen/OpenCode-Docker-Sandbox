FROM ubuntu:26.04

ARG DEBIAN_FRONTEND=noninteractive
ARG OLLAMA_HOST=http://host.docker.internal:11434
ARG HOST_UID
ARG HOST_GID
ARG NODE_MAJOR=22
ARG DOTNET_CHANNEL=9.0

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DOTNET_NOLOGO=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    NODE_OPTIONS=--no-warnings \
    EDITOR=nvim \
    VISUAL=nvim \
    OLLAMA_HOST=${OLLAMA_HOST} \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        software-properties-common \
        apt-transport-https \
        unzip \
        zstd \
        libicu78 \
        build-essential \
        cmake \
        make \
        ninja-build \
        gcc \
        g++ \
        clang \
        llvm \
        lld \
        lldb \
        ca-certificates-java \
        python3 \
        python3-pip \
        python3-venv \
        pipx \
    && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm@latest \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* ~/.npm

RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel ${DOTNET_CHANNEL} --install-dir /usr/share/dotnet --no-path \
    && /tmp/dotnet-install.sh --channel ${DOTNET_CHANNEL} --runtime aspnetcore --install-dir /usr/share/dotnet --no-path \
    && /tmp/dotnet-install.sh --channel ${DOTNET_CHANNEL} --runtime dotnet --install-dir /usr/share/dotnet --no-path \
    && ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet \
    && rm -f /tmp/dotnet-install.sh \
    && dotnet --info

RUN apt-get update \
    && apt-get install -y --no-install-recommends neovim \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest \
    && npm cache clean --force \
    && rm -rf /tmp/* ~/.npm

RUN mkdir -p /etc/ollama \
    && echo "[Service]\nEnvironment=\"OLLAMA_HOST=${OLLAMA_HOST}\"" > /etc/ollama/ollama.conf \
    && curl -fsSL https://ollama.com/install.sh -o /tmp/ollama-install.sh \
    && sh /tmp/ollama-install.sh \
    && rm -f /tmp/ollama-install.sh \
    && rm -rf /usr/local/lib/ollama /usr/share/ollama /root/.ollama

RUN EXISTING_GROUP="$(awk -F: -v gid="${HOST_GID}" '$3==gid {print $1; exit}' /etc/group)" \
    && if [ -z "${EXISTING_GROUP}" ]; then \
         groupadd -g "${HOST_GID}" developer && PRIMARY_GROUP=developer; \
       else \
         PRIMARY_GROUP="${EXISTING_GROUP}" \
         && if ! getent group developer > /dev/null; then \
              groupadd developer; \
            fi; \
       fi \
    && EXISTING_UID_USER="$(awk -F: -v uid="${HOST_UID}" '$3==uid {print $1; exit}' /etc/passwd)" \
    && if [ -n "${EXISTING_UID_USER}" ] && [ "${EXISTING_UID_USER}" != "developer" ]; then \
         if [ -d "/home/${EXISTING_UID_USER}" ]; then \
           rm -rf /home/developer && mv "/home/${EXISTING_UID_USER}" /home/developer; \
         fi \
         && usermod -l developer -d /home/developer "${EXISTING_UID_USER}" \
         && usermod -G developer developer; \
       fi \
    && if ! getent passwd developer > /dev/null; then \
         useradd -u "${HOST_UID}" -g "${PRIMARY_GROUP}" -G developer -m -s /bin/bash developer; \
       fi \
    && passwd -d developer \
    && mkdir -p /etc/nvim /home/developer/.config/nvim /source /home/developer/.cache /home/developer/.local/share /home/developer/.npm-global \
    && chown -R developer:developer /home/developer /source \
    && chmod 755 /source

RUN apt-get purge -y --auto-remove sudo libsudo-dev 2>/dev/null || true \
    && for f in /usr/bin/sudo /usr/bin/su /usr/bin/sudoedit /usr/bin/sudoreplay /usr/bin/pkexec; do [ -e "$f" ] && rm -f "$f"; done \
    && find /usr/lib /usr/libexec /usr/share -name '*sudo*' -prune -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /var/lib/apt/lists/* /etc/sudoers.d /etc/sudoers 2>/dev/null || true

RUN tee /etc/nvim/init.vim /home/developer/.config/nvim/init.vim > /dev/null <<'NVIMCONF'
syntax on
filetype plugin indent on
set nocompatible

set number
set relativenumber

set tabstop=4
set softtabstop=4
set shiftwidth=4
set shiftround
set expandtab

set autoindent
set smartindent

set background=dark
set mouse=a
set encoding=utf-8
NVIMCONF

RUN chown developer:developer /home/developer/.config/nvim/init.vim

COPY --chown=root:root scripts/oc-entrypoint.sh /usr/local/bin/oc-entrypoint
RUN chmod 755 /usr/local/bin/oc-entrypoint

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /tmp/* /var/tmp/* /root/.cache /root/.npm

USER developer
WORKDIR /source

CMD ["/usr/local/bin/oc-entrypoint"]