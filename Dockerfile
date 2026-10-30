FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    lsb-release \
    dante-server \
    iproute2 \
    iptables

RUN curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/cloudflare-client.list

RUN apt-get update && apt-get install -y cloudflare-warp

COPY danted.conf /etc/danted.conf

EXPOSE 1080

COPY exec.sh /exec.sh
RUN chmod +x /exec.sh
CMD ["/exec.sh"]
