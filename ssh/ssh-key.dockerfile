FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y openssh-server apache2 openssl git ruby ruby-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH directory structure
RUN mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Copy public key and set permissions
COPY ./dockerkey.pub /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# Configure SSH server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Add to your Dockerfile before CMD
RUN mkdir -p /etc/apache2/ssl && \
    openssl req -x509 -newkey rsa:4096 \
    -keyout /etc/apache2/ssl/key.pem \
    -out /etc/apache2/ssl/cert.pem \
    -days 365 -nodes \
    -subj '/CN=localhost' \
    -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'

# Add port configuration
RUN echo "Listen 0.0.0.0:443" >> /etc/apache2/ports.conf

# Install BeEF dependencies first
RUN gem install bundler

# Clone and configure BeEF
RUN git clone https://github.com/beefproject/beef && \
    cd beef && \
    sed -i 's/user: "beef"/user: "admin"/' config.yaml && \
    sed -i 's/passwd: "beef"/passwd: "J7q!Z#vE2m*K"/' config.yaml && \
    sed -i 's/0.0.0.0\/22/192.168.1.0\/24/' config.yaml && \
    bundle install

EXPOSE 22

CMD ["sh", "-c", "service apache2 start && /usr/sbin/sshd -D -e"]