FROM jenkins/inbound-agent:latest

USER root

# Install Python and essential tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    docker.io \
    wget \
    curl \
    perl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Trivy for security scanning
RUN wget -qO- https://github.com/aquasecurity/trivy/releases/download/v0.48.0/trivy_0.48.0_Linux-64bit.tar.gz | tar -xz \
    && mv trivy /usr/local/bin/

# Verify installations
RUN python3 --version && \
    docker --version && \
    kubectl version --client && \
    trivy --version

USER jenkins