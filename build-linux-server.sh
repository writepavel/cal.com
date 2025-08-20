#!/bin/bash
# build-linux-server.sh - Simple Cal.com build for Linux servers
# Работает на обычном Docker Engine без buildx или GitHub CLI

set -e

echo "🚀 Сборка Cal.com для Linux сервера..."
echo ""

# Проверить Docker
if ! docker --version &> /dev/null; then
    echo "❌ Ошибка: Docker не установлен"
    exit 1
fi

echo "📋 Информация о системе:"
echo "  Docker: $(docker --version)"
echo "  Platform: $(uname -m)"
echo "  OS: $(uname -s)"
echo ""

# Проверить файлы проекта
echo "📦 Проверка файлов проекта:"
required_files=("package.json" "yarn.lock" ".yarnrc.yml" "turbo.json" "i18n.json" "Dockerfile.root")
missing_files=()

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo ""
    echo "❌ Отсутствуют необходимые файлы:"
    printf '  - %s\n' "${missing_files[@]}"
    exit 1
fi

# Проверить директории
echo ""
echo "📁 Проверка директорий:"
required_dirs=("apps" "packages" "scripts")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir/ ($(ls "$dir" | wc -l) элементов)"
    else
        echo "  ❌ $dir/"
        exit 1
    fi
done

echo ""

# Определить метод аутентификации
PUSH_IMAGE=${PUSH_IMAGE:-true}
if [ "$PUSH_IMAGE" = "true" ]; then
    echo "🔐 Настройка аутентификации в GHCR..."
    
    # Попробовать разные методы аутентификации
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "  Используется GITHUB_TOKEN из переменной окружения"
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u writepavel --password-stdin
    elif [ -n "$GHCR_TOKEN" ]; then
        echo "  Используется GHCR_TOKEN из переменной окружения"
        echo "$GHCR_TOKEN" | docker login ghcr.io -u writepavel --password-stdin
    elif command -v gh &> /dev/null; then
        echo "  Используется GitHub CLI"
        gh auth token | docker login ghcr.io -u writepavel --password-stdin
    else
        echo ""
        echo "⚠️  Аутентификация не настроена!"
        echo "  Настройте один из способов:"
        echo "    1. Экспортируйте GITHUB_TOKEN: export GITHUB_TOKEN=your_token"
        echo "    2. Экспортируйте GHCR_TOKEN: export GHCR_TOKEN=your_token" 
        echo "    3. Установите GitHub CLI: apt install gh"
        echo "    4. Запустите без push: PUSH_IMAGE=false $0"
        echo ""
        read -p "Продолжить без push? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        PUSH_IMAGE=false
    fi
fi

# Определить теги образа
IMAGE_REPO="ghcr.io/writepavel/cal.com"
BUILD_DATE=$(date +%Y%m%d-%H%M%S)
IMAGE_TAGS=(
    "${IMAGE_REPO}:linux-zoho-fix"
    "${IMAGE_REPO}:linux-latest"
    "${IMAGE_REPO}:linux-${BUILD_DATE}"
)

echo ""
echo "🏗️ Начинаем сборку..."
echo "  📁 Dockerfile: Dockerfile.root"
echo "  🏷️ Теги образа:"
for tag in "${IMAGE_TAGS[@]}"; do
    echo "    - $tag"
done
echo "  ⏱️  Ожидаемое время на Linux: 15-30 минут"
echo ""

# Проверить buildx или использовать обычный docker build
if docker buildx version &> /dev/null; then
    echo "🔧 Используется docker buildx"
    BUILD_CMD="docker buildx build --platform linux/amd64 --load"
else
    echo "🔧 Используется обычный docker build"
    BUILD_CMD="docker build"
fi

# Подготовить теги для команды сборки
TAG_ARGS=""
for tag in "${IMAGE_TAGS[@]}"; do
    TAG_ARGS="$TAG_ARGS -t $tag"
done

# Выполнить сборку
$BUILD_CMD \
  -f Dockerfile.root \
  $TAG_ARGS \
  --build-arg NEXT_PUBLIC_LICENSE_CONSENT=agree \
  --build-arg CALCOM_TELEMETRY_DISABLED=1 \
  --build-arg DATABASE_URL=postgresql://placeholder:placeholder@placeholder:5432/placeholder \
  --build-arg NEXTAUTH_SECRET=docker-build-secret \
  --build-arg CALENDSO_ENCRYPTION_KEY=docker-build-key-change-in-production-32bytes \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Сборка завершена успешно!"
    echo ""
    
    # Push образы если настроена аутентификация
    if [ "$PUSH_IMAGE" = "true" ]; then
        echo "📤 Загрузка образов в GHCR..."
        for tag in "${IMAGE_TAGS[@]}"; do
            echo "  Pushing $tag..."
            docker push "$tag"
        done
        echo ""
        echo "✅ Все образы загружены в GHCR!"
        
        # Показать информацию об образе
        echo ""
        echo "🔍 Информация о загруженном образе:"
        if docker buildx version &> /dev/null; then
            docker buildx imagetools inspect "${IMAGE_TAGS[0]}" || true
        fi
    else
        echo "⏭️  Push пропущен (образ собран локально)"
    fi
    
    echo ""
    echo "📦 Локальные образы:"
    docker images | grep "${IMAGE_REPO}" || echo "Нет локальных образов"
    
    echo ""
    echo "📋 Доступные теги в GHCR:"
    for tag in "${IMAGE_TAGS[@]}"; do
        echo "  - $tag"
    done
    
    echo ""
    echo "🚀 Для запуска на сервере:"
    echo "  docker pull ${IMAGE_TAGS[0]}"
    echo ""
    echo "  docker run -d \\"
    echo "    --name calcom-linux \\"
    echo "    -e ZOHOCALENDAR_CLIENT_ID=your-client-id \\"
    echo "    -e ZOHOCALENDAR_CLIENT_SECRET=your-client-secret \\"
    echo "    -e DATABASE_URL=your-database-url \\"
    echo "    -e NEXTAUTH_SECRET=your-secret \\"
    echo "    -e CALENDSO_ENCRYPTION_KEY=your-key \\"
    echo "    -e NEXT_PUBLIC_WEBAPP_URL=https://your-domain.com \\"
    echo "    -p 3000:3000 \\"
    echo "    ${IMAGE_TAGS[0]}"
    
else
    echo ""
    echo "❌ Ошибка сборки"
    echo ""
    echo "🔧 Возможные причины:"
    echo "  1. Недостаточно места на диске"
    echo "  2. Недостаточно памяти (рекомендуется 4GB+)"
    echo "  3. Проблемы с сетью при скачивании зависимостей"
    echo ""
    echo "💡 Попробуйте:"
    echo "  - Освободить место: docker system prune -a"
    echo "  - Увеличить swap память"
    echo "  - Проверить интернет соединение"
    exit 1
fi