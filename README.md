# Cloudflare WARP Proxy

Docker image that runs Cloudflare WARP with a SOCKS5 proxy (dante-server) for routing traffic through WARP.

## System Requirements

- Docker installed
- Root/sudo privileges
- Linux with TUN device support (or macOS/Windows with WSL2)

## Quick Start

### 1. Build the image

```bash
docker build -t warp-proxy .
```

If the build fails due to network issues, try:

```bash
# Use host network
docker build --network=host -t warp-proxy .

# Or use custom DNS
docker build --dns=8.8.8.8 -t warp-proxy .
```

### 2. Run the container

```bash
docker run -d \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -p 1080:1080 \
  warp-proxy
```

For automatic restart on failure:

```bash
docker run -d \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  -p 1080:1080 \
  --restart unless-stopped \
  warp-proxy
```

## Proxy Configuration

After the container starts, use these settings in your applications:

- **Host**: `localhost` or `127.0.0.1`
- **Port**: `1080`
- **Type**: SOCKS5
- **Authentication**: None

## Usage Examples

### Browser
Configure proxy in browser settings: SOCKS5 `127.0.0.1:1080`

### Telegram
Settings → Data and Storage → Proxy Settings → Add Proxy:
- Type: SOCKS5
- Hostname: `127.0.0.1`
- Port: `1080`
- Username/Password: empty

### Command line

```bash
# curl
curl --socks5 127.0.0.1:1080 https://ipinfo.io

# wget
wget --proxy=on --socks-proxy=127.0.0.1:1080 https://ipinfo.io
```

## Monitoring

```bash
# View logs
docker logs <container_id>

# Follow logs
docker logs -f <container_id>

# Check running containers
docker ps

# Enter container for debugging
docker exec -it <container_id> bash
```

## Troubleshooting

### Container exits immediately
```bash
# Check logs
docker logs <container_id>

# Run interactively to debug
docker run -it --cap-add=NET_ADMIN --device /dev/net/tun -p 1080:1080 warp-proxy bash
```

### Cannot connect to proxy
1. Verify container is running: `docker ps`
2. Check port 1080: `netstat -an | grep 1080`
3. Check firewall rules

### WARP registration fails
- Verify internet connectivity
- Restart container: `docker restart <container_id>`

## Project Structure

```
warp-proxy/
├── Dockerfile       # Builds Ubuntu + WARP + dante-server
├── danted.conf      # SOCKS5 proxy configuration (port 1080)
├── exec.sh          # Entrypoint: starts WARP, registers, connects, runs danted
└── README.md        # This file
```

## How It Works

1. **Dockerfile** installs `cloudflare-warp` and `dante-server` on Ubuntu
2. **exec.sh** (entrypoint):
   - Starts `warp-svc` daemon
   - Registers WARP account (persists to `/register-warp`)
   - Connects to WARP
   - Starts `danted` SOCKS5 proxy on port 1080
   - Monitors both processes and restarts if they die
3. **danted.conf** configures dante to listen on `0.0.0.0:1080` with no auth

## Stop and Remove

```bash
docker stop <container_id>
docker rm <container_id>
docker rmi warp-proxy  # optional: remove image
```