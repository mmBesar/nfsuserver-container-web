# Use Alpine Linux for minimal size, especially good for Pi4
FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    make \
    gcc \
    g++ \
    musl-dev

# Clone and build the server
WORKDIR /build
RUN git clone https://github.com/HarpyWar/nfsuserver.git
WORKDIR /build/nfsuserver/nfsuserver
RUN make

# Runtime stage - minimal Alpine image
FROM alpine:3.19

# Install runtime dependencies including web server
RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    apache2 \
    php82 \
    php82-apache2 \
    php82-session \
    php82-json \
    php82-mbstring \
    supervisor

# Create non-root user for security
RUN addgroup -g 1000 nfsu && \
    adduser -D -u 1000 -G nfsu nfsu

# Copy the built binary and web files
COPY --from=builder /build/nfsuserver/nfsuserver/nfsuserver /usr/local/bin/
COPY --from=builder /build/nfsuserver/web /var/www/localhost/htdocs/

# Create necessary directories
RUN mkdir -p /data /var/log/nfsu /run/apache2 /var/log/supervisor /var/log/apache2 && \
    chown nfsu:nfsu /data /var/log/nfsu && \
    chown -R apache:apache /var/www/localhost/htdocs/

# Configure Apache
RUN sed -i 's/#ServerName www.example.com:80/ServerName localhost:80/' /etc/apache2/httpd.conf && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/httpd.conf && \
    sed -i 's/:80>/:8080>/' /etc/apache2/httpd.conf && \
    echo "LoadModule rewrite_module modules/mod_rewrite.so" >> /etc/apache2/httpd.conf

# Create supervisor configuration
RUN mkdir -p /etc/supervisor/conf.d
COPY supervisord.conf /etc/supervisord.conf

# Set working directory
WORKDIR /data

# Expose all NFSU ports + web interface
EXPOSE 10900/tcp \
       10901/tcp \
       10980/tcp \
       10800/tcp \
       10800/udp \
       8080/tcp

# Health check for both services
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD pgrep nfsuserver && pgrep httpd || exit 1

# Use supervisor to run both services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
