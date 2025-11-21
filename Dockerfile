FROM perl:5.38-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    make \
    libssl-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Perl dependencies
RUN cpanm --notest \
    URI \
    JSON::XS \
    AnyEvent \
    YAML::XS \
    AnyEvent::HTTPD \
    AnyEvent::HTTP \
    EV \
    AnyEvent::WebSocket::Server \
    Template

# Set working directory
WORKDIR /app

# Copy required files and directories
COPY proxy.yml .
COPY proxy-server.pl .
COPY index.tt .
COPY lib/ ./lib/

# Make the server executable
RUN chmod +x proxy-server.pl

# Expose the proxy port
EXPOSE 2999

# Expose the WebSocket port
EXPOSE 8002

# Run the proxy server
CMD ["perl", "proxy-server.pl"]
