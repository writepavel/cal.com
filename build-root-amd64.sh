#!/bin/bash
# build-root-amd64.sh - Build Cal.com for linux/amd64 from root directory

set -e

echo "🚀 Building Cal.com for linux/amd64 from root directory..."
echo ""

# Проверить buildx
if ! docker buildx version &> /dev/null; then
    echo "❌ Ошибка: Docker buildx не установлен"
    exit 1
fi

# Аутентификация
echo "🔐 Аутентификация в GHCR..."
if ! gh auth token | docker login ghcr.io -u writepavel --password-stdin; then
    echo "❌ Ошибка аутентификации. Убедитесь что 'gh auth login' выполнен"
    exit 1
fi

# Создать builder если не существует
echo "🔧 Настройка buildx builder..."
docker buildx create --name calcom-root-amd64-builder --use 2>/dev/null || docker buildx use calcom-root-amd64-builder

# Показать информацию о builder
echo "📋 Информация о builder:"
docker buildx ls | grep calcom-root-amd64-builder || echo "Using default builder"

echo ""
echo "🏗️ Начинаем сборку для linux/amd64 из корневой директории..."
echo "📁 Используется Dockerfile.root (сборка из корня проекта)"
echo "⚠️  Это может занять 60-120 минут на Mac из-за кросс-платформенной компиляции"
echo ""

# Показать какие файлы будут использованы
echo "📦 Проверка файлов в корневой директории:"
ls -la package.json yarn.lock .yarnrc.yml turbo.json i18n.json 2>/dev/null || echo "Некоторые файлы отсутствуют"
echo "📁 apps/: $(ls -la apps/ | wc -l) элементов"
echo "📁 packages/: $(ls -la packages/ | wc -l) элементов"
echo "📁 scripts/: $(ls -la scripts/ | wc -l) элементов"
echo ""

# Сборка и загрузка
docker buildx build --platform linux/amd64 \
  -f Dockerfile.root \
  -t ghcr.io/writepavel/cal.com:root-zoho-fix-amd64 \
  -t ghcr.io/writepavel/cal.com:root-latest-amd64 \
  --build-arg NEXT_PUBLIC_LICENSE_CONSENT=agree \
  --build-arg CALCOM_TELEMETRY_DISABLED=1 \
  --build-arg DATABASE_URL=postgresql://placeholder:placeholder@placeholder:5432/placeholder \
  --build-arg NEXTAUTH_SECRET=docker-build-secret \
  --build-arg CALENDSO_ENCRYPTION_KEY=docker-build-key-change-in-production-32bytes \
  --push \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Образ успешно собран и загружен!"
    echo ""
    echo "📦 Доступные теги:"
    echo "  - ghcr.io/writepavel/cal.com:root-zoho-fix-amd64"
    echo "  - ghcr.io/writepavel/cal.com:root-latest-amd64"
    echo ""
    echo "🔍 Проверка архитектуры образа:"
    docker buildx imagetools inspect ghcr.io/writepavel/cal.com:root-zoho-fix-amd64
    echo ""
    echo "📋 Особенности этого образа:"
    echo "  ✅ Собран из корневой директории (без calcom/ поддиректории)"
    echo "  ✅ Включает фикс OAuth scope для Zoho Calendar"
    echo "  ✅ Включает фикс сидинга базы данных для Zoho Calendar"
    echo "  ✅ Архитектура: linux/amd64 (совместим с большинством серверов)"
    echo ""
    echo "🚀 Для запуска на Linux сервере:"
    echo "  docker pull ghcr.io/writepavel/cal.com:root-zoho-fix-amd64"
    echo ""
    echo "  docker run -d \\"
    echo "    --name calcom-root-amd64 \\"
    echo "    --platform linux/amd64 \\"
    echo "    -e ZOHOCALENDAR_CLIENT_ID=your-client-id \\"
    echo "    -e ZOHOCALENDAR_CLIENT_SECRET=your-client-secret \\"
    echo "    -e DATABASE_URL=your-database-url \\"
    echo "    -e NEXTAUTH_SECRET=your-secret \\"
    echo "    -e CALENDSO_ENCRYPTION_KEY=your-key \\"
    echo "    -e NEXT_PUBLIC_WEBAPP_URL=https://cal.resultcrafter.com \\"
    echo "    -p 3000:3000 \\"
    echo "    ghcr.io/writepavel/cal.com:root-zoho-fix-amd64"
    echo ""
    echo "📝 Для docker-compose обновите image в вашем compose файле:"
    echo "  image: ghcr.io/writepavel/cal.com:root-zoho-fix-amd64"
else
    echo "❌ Ошибка сборки"
    echo ""
    echo "🔧 Возможные причины:"
    echo "  1. Отсутствуют необходимые файлы в корневой директории"
    echo "  2. Проблемы с сетью при загрузке зависимостей"
    echo "  3. Недостаточно памяти для Docker (рекомендуется 8GB+)"
    echo ""
    echo "💡 Попробуйте:"
    echo "  - Проверить наличие файлов: ls package.json yarn.lock apps/ packages/"
    echo "  - Увеличить память Docker Desktop в настройках"
    echo "  - Очистить кеш: docker buildx prune"
    exit 1
fi