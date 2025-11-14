FROM ubuntu:latest

# Set the default shell to bash
SHELL ["/bin/bash", "-c"]

# Install some base tools
RUN apt-get update && apt-get install -y curl wget jq git gnupg unzip whiptail bc bsdmainutils apache2-utils && rm -rf /var/lib/apt/lists/*

# Install some basic troubleshooting tools:
RUN apt-get update && apt-get install -y sysstat && rm -rf /var/lib/apt/lists/*

# Install some network troubleshooting tools:
RUN apt-get update && apt-get install -y iputils-ping wget curl iproute2 net-tools htop netcat-traditional telnet vim traceroute dnsutils tcpdump conntrack && rm -rf /var/lib/apt/lists/*

# Install some dependencies for mydumper
RUN apt-get update && apt-get install -y pv lsb-release gettext-base zstd mysql-client libatomic1 libglib2.0-0 libpcre3 && rm -rf /var/lib/apt/lists/*

# Install some other tools via apt-get
RUN apt-get update && apt-get install -y redis-tools postgresql-client && rm -rf /var/lib/apt/lists/*

# Install some devops tools:

# yq
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq \
    && yq --version

# kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && kubectl version --client

# cilium cli
RUN CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt) \
    && CLI_ARCH=$(uname -m | grep -q aarch64 && echo arm64 || echo amd64) \
    && curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum} \
    && sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum \
    && tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin \
    && rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum} \
    && cilium version --client

# eksctl
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp \
    && mv /tmp/eksctl /usr/local/bin \
    && eksctl version

# kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash \
    && install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize \
    && rm kustomize \
    && kustomize version

# argocd
RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
    && install -m 555 argocd-linux-amd64 /usr/local/bin/argocd \
    && rm argocd-linux-amd64 \
    && argocd version --client --short

# helm
RUN apt-get install curl gpg apt-transport-https --yes \
    && curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install helm -y \
    && rm -rf /var/lib/apt/lists/*

# aws cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

# docker
RUN apt update \
    && apt install apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release -y \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt update \
    && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin -y \
    && adduser ubuntu docker \
    && rm -rf /var/lib/apt/lists/*

# mydumper - WARNING !!! - OVERRIDEN HARDCODED VERSION AS THE NEWER VERSION "v0.18.1-1" IS BROKEN FOR RDS FOR NOW.
RUN MYDUMPER_VERSION="$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/mydumper/mydumper/releases/latest | cut -d'/' -f8)" \
    && MYDUMPER_VERSION="v0.17.1-1" \
    && wget "https://github.com/mydumper/mydumper/releases/download/${MYDUMPER_VERSION}/mydumper_${MYDUMPER_VERSION:1}.$(lsb_release -cs)_amd64.deb" \
    && dpkg -i "mydumper_${MYDUMPER_VERSION:1}.$(lsb_release -cs)_amd64.deb" \
    && rm -f "mydumper_${MYDUMPER_VERSION:1}.$(lsb_release -cs)_amd64.deb" \
    && mydumper --version

# node
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && npm install -g yarn@latest \
    && node -v

# Clone all scripts in ubuntu-scripts, for easy access just in case.
ADD https://api.github.com/repos/JimCronqvist/ubuntu-scripts/compare/master...HEAD /dev/null
RUN git clone https://github.com/JimCronqvist/ubuntu-scripts /scripts
RUN chmod +x /scripts/*.sh

# Set the working directory to the home folder
WORKDIR /root

