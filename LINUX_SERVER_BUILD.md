# Building Cal.com on Linux Server

Simplified instructions for building Cal.com with Zoho Calendar fixes on a regular Linux server without Docker Desktop.

## Requirements

### Minimum requirements:
- **Linux server** (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- **Docker Engine** 19.03+ (Docker Desktop not required)
- **4GB RAM** minimum (8GB recommended)
- **10GB free disk space**
- **Internet connection** for downloading dependencies

### Installing Docker on Linux:

#### Ubuntu/Debian:
```bash
# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### CentOS/RHEL:
```bash
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

## Project Setup

### 1. Clone Repository
```bash
git clone https://github.com/writepavel/cal.com.git
cd cal.com
```

### 2. GHCR Authentication Setup

Choose one method:

#### Method 1: GitHub Personal Access Token
```bash
# Create token at https://github.com/settings/tokens
# Permissions: read:packages, write:packages
export GITHUB_TOKEN=your_github_token_here
```

#### Method 2: GHCR_TOKEN Variable
```bash
export GHCR_TOKEN=your_github_token_here
```

#### Method 3: Manual Authentication
```bash
docker login ghcr.io -u writepavel
# Enter your GitHub token as password
```

#### Method 4: Local Build Only (no push)
```bash
export PUSH_IMAGE=false
```

## Building

### Quick Build (recommended)
```bash
./build-linux-server.sh
```

### Manual Build
```bash
# Check files
ls -la package.json yarn.lock Dockerfile.root

# Build image
docker build -f Dockerfile.root \
  -t ghcr.io/writepavel/cal.com:linux-zoho-fix \
  --build-arg NEXT_PUBLIC_LICENSE_CONSENT=agree \
  --build-arg CALCOM_TELEMETRY_DISABLED=1 \
  --build-arg DATABASE_URL=postgresql://placeholder:placeholder@placeholder:5432/placeholder \
  --build-arg NEXTAUTH_SECRET=docker-build-secret \
  --build-arg CALENDSO_ENCRYPTION_KEY=docker-build-key-change-in-production-32bytes \
  .

# Push to registry (optional)
docker push ghcr.io/writepavel/cal.com:linux-zoho-fix
```

## Linux Build Features

### ✅ Advantages:
- **Fast build**: 15-30 minutes (vs 60-120 on Mac)
- **Native architecture**: No emulation
- **Fewer requirements**: No Docker Desktop needed
- **Simple setup**: One script

### 🔧 Automatic fallbacks:
- **buildx**: If available - used, if not - regular `docker build`
- **Authentication**: Multiple methods checked in sequence
- **Platform**: Automatically Linux/AMD64

## Build Results

After successful build, these images will be created:
- `ghcr.io/writepavel/cal.com:linux-zoho-fix`
- `ghcr.io/writepavel/cal.com:linux-latest`
- `ghcr.io/writepavel/cal.com:linux-YYYYMMDD-HHMMSS`

## Running

### Docker Run
```bash
docker run -d \
  --name calcom-linux \
  -e ZOHOCALENDAR_CLIENT_ID="your-zoho-client-id" \
  -e ZOHOCALENDAR_CLIENT_SECRET="your-zoho-client-secret" \
  -e DATABASE_URL="postgresql://user:pass@host:5432/calcom" \
  -e NEXTAUTH_SECRET="your-nextauth-secret" \
  -e CALENDSO_ENCRYPTION_KEY="your-32-char-encryption-key" \
  -e NEXT_PUBLIC_WEBAPP_URL="https://your-domain.com" \
  -p 3000:3000 \
  --restart unless-stopped \
  ghcr.io/writepavel/cal.com:linux-zoho-fix
```

### Docker Compose
```yaml
version: '3.8'

services:
  calcom:
    image: ghcr.io/writepavel/cal.com:linux-zoho-fix
    container_name: calcom-linux
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/calcom
      - NEXTAUTH_SECRET=your-secret-here
      - CALENDSO_ENCRYPTION_KEY=your-32-char-key-here
      - NEXT_PUBLIC_WEBAPP_URL=https://your-domain.com
      - ZOHOCALENDAR_CLIENT_ID=your-zoho-client-id
      - ZOHOCALENDAR_CLIENT_SECRET=your-zoho-client-secret
    ports:
      - "3000:3000"
    depends_on:
      - db
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=calcom
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

## Included Fixes

### ✅ Zoho Calendar OAuth Fix
- Fixed scope parameters in OAuth URL
- Now compatible with Zoho OAuth server

### ✅ Zoho Calendar Database Seeding
- Automatic Zoho Calendar app creation in database
- Proper credentials saving on first run

### ✅ Verified Scripts
- `start.sh` - Correct application startup
- `replace-placeholder.sh` - Runtime URL replacement
- `wait-for-it.sh` - Database readiness check

## Troubleshooting

### Authentication Errors
```bash
# Check token
echo $GITHUB_TOKEN | wc -c  # Should be 40+ characters

# Test authentication
docker login ghcr.io -u writepavel

# Alternative - local build
PUSH_IMAGE=false ./build-linux-server.sh
```

### Memory Issues
```bash
# Check memory
free -h

# Add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Clear Docker cache
docker system prune -a
```

### Network Errors
```bash
# Check connections
curl -I https://registry.npmjs.org/
curl -I https://ghcr.io/v2/

# Configure proxy (if needed)
# Add to /etc/docker/daemon.json:
{
  "proxies": {
    "http-proxy": "http://proxy.example.com:8080",
    "https-proxy": "http://proxy.example.com:8080"
  }
}
```

### Slow Build
```bash
# Use local mirrors
export NPM_CONFIG_REGISTRY=http://your-local-npm-mirror/
export YARN_REGISTRY=http://your-local-npm-mirror/

# Increase parallelism
export NODE_OPTIONS="--max-old-space-size=4096"
```

## Build Monitoring

### View logs in real-time
```bash
# In separate terminal
docker logs -f container_name

# Monitor resources
watch "docker stats --no-stream"
```

### Check Results
```bash
# Check created images
docker images | grep calcom

# Check image size
docker images ghcr.io/writepavel/cal.com:linux-zoho-fix

# Test locally
docker run --rm -p 3000:3000 \
  -e DATABASE_URL=postgresql://test:test@test:5432/test \
  -e NEXTAUTH_SECRET=test-secret \
  -e CALENDSO_ENCRYPTION_KEY=test-key-32-characters-long-test \
  ghcr.io/writepavel/cal.com:linux-zoho-fix
```

## CI/CD Automation

### GitHub Actions
```yaml
- name: Build Cal.com
  run: |
    export GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
    ./build-linux-server.sh
```

### GitLab CI
```yaml
build:
  script:
    - export GHCR_TOKEN=$CI_JOB_TOKEN
    - ./build-linux-server.sh
```

---

**Build time on typical Linux server**: 15-30 minutes  
**Final image size**: ~1.6GB  
**Includes**: All Zoho Calendar integration fixes