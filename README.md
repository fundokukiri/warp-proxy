# Cloudflare WARP Proxy Setup Guide

Complete guide to set up and run Cloudflare WARP Proxy using Docker.

## 📋 System Requirements

- Docker installed
- sudo/admin privileges
- Operating system with TUN device support (Linux/macOS/Windows with WSL2)

## 🚀 Installation Guide

### Step 1: Clone the repository

```bash
git clone https://github.com/fundokukiri/cloudflare-local-proxy.git
```

### Step 2: Navigate to project directory

```bash
cd cloudflare-local-proxy
```

### Step 3: Build Docker image

```bash
docker build -t warp-proxy .
```

> ⏱️ **Note**: The build process may take 3-5 minutes depending on your network speed

### Step 4: Run the container

```bash
docker run -dit --cap-add=NET_ADMIN --device /dev/net/tun -p 1080:1080 warp-proxy
```

## 📊 Status Monitoring

### View container logs

```bash
docker logs <container_id>
```

### Check running containers

```bash
docker ps
```

### Connect to container (for debugging)

```bash
docker exec -it <container_id> bash
```

## 🔧 Proxy Configuration

After the container runs successfully, you can use the proxy with these settings:

- **Host**: `localhost` or `127.0.0.1`
- **Port**: `1080`
- **Type**: SOCKS5
- **Authentication**: None required

## 📱 Usage with Applications

### Web browsers
1. Open Settings → Proxy
2. Select SOCKS5
3. Enter: `127.0.0.1:1080`

### Telegram
1. Open Telegram application
2. Go to Settings → Data and Storage → Proxy Settings
3. Add New Proxy with the following settings:
   - **Type**: SOCKS5
   - **Hostname**: `127.0.0.1`
   - **Port**: `1080`
   - **Username**: Leave empty
   - **Password**: Leave empty
4. Click "Save" and enable the proxy

### Terminal/Command line
```bash
# Using with curl
curl --socks5 127.0.0.1:1080 https://ipinfo.io

# Using with wget
wget --proxy=on --socks-proxy=127.0.0.1:1080 https://ipinfo.io
```

## 🔍 Troubleshooting

### Container exits immediately
```bash
# Check logs for errors
docker logs <container_id>

# Try running in interactive mode
docker run -it --cap-add=NET_ADMIN --device /dev/net/tun -p 1080:1080 warp-proxy bash
```

### Cannot connect to proxy
1. Check if container is running: `docker ps`
2. Check if port 1080 is occupied: `netstat -an | grep 1080`
3. Check if firewall is blocking the port

### WARP registration failed
- Check internet connection
- Try restarting container: `docker restart <container_id>`

## 🛑 Stop and Remove Container

```bash
# Stop container
docker stop <container_id>

# Remove container
docker rm <container_id>

# Remove image (if needed)
docker rmi warp-proxy
```

## 📝 Project Structure

```
cloudflare-warp-proxy-telegram/
├── Dockerfile          # Docker image build file
├── danted.conf         # SOCKS5 proxy configuration
├── exec.sh             # Initializing
└── README.md           # This guide file
```

## ⚡ Performance

- **RAM**: ~100-200MB
- **CPU**: Minimal (< 5%)
- **Network**: Depends on usage traffic

## 🔒 Security

⚠️ **Important Notes**: 
- This proxy runs without authentication
- Should only be used on personal machines or trusted networks
- Do not expose port 1080 to the public internet

## 📞 Support

If you encounter issues:
1. Check container logs
2. Ensure Docker has access to TUN device
3. Verify internet connection

---

**Happy proxying! 🎉**
