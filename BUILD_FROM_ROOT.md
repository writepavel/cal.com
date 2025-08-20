# Building Cal.com from Root Directory

Instructions for building Cal.com Docker image with Zoho Calendar fixes from the project root directory.

## New Build Structure

### Problem
The standard `Dockerfile` expects code in a `calcom/` subdirectory, but the actual code with fixes is located in the root directory.

### Solution
A new build process has been created that works directly with code from the root directory.

## Root Build Files

### 1. Dockerfile.root
Modified version of Dockerfile that:
- ✅ Copies files from root directory (without `calcom/` prefix)
- ✅ Preserves internal container structure (`/calcom` workdir)
- ✅ Includes all fixes (OAuth scope + seeding)
- ✅ Uses correct scripts from official image

### 2. build-root-amd64.sh
Script for building linux/amd64 version:
- ✅ Automatic GHCR authentication
- ✅ buildx setup for cross-platform building
- ✅ Check for required files
- ✅ Detailed build process information

## Usage

### Docker Compose (рекомендуется)
```bash
# Development stack (builds locally from root)
docker-compose up

# Production-ready with prebuilt image (faster)
docker-compose -f docker-compose.zoho.yml up

# Or build locally using the zoho compose file
# (uncomment build section, comment out image line)
```

### Скрипты сборки

#### Для Linux серверов (рекомендуется)
```bash
# Простая сборка на Linux сервере
./build-linux-server.sh
```

#### Для разработки (Mac/Windows)
```bash
# Сборка и загрузка в GHCR
./build-root-amd64.sh
```

### Ручная сборка
```bash
# Создать builder
docker buildx create --name calcom-root-builder --use

# Собрать для linux/amd64
docker buildx build --platform linux/amd64 \
  -f Dockerfile.root \
  -t ghcr.io/writepavel/cal.com:root-zoho-fix-amd64 \
  --build-arg NEXT_PUBLIC_LICENSE_CONSENT=agree \
  --build-arg CALCOM_TELEMETRY_DISABLED=1 \
  --build-arg DATABASE_URL=postgresql://placeholder:placeholder@placeholder:5432/placeholder \
  --build-arg NEXTAUTH_SECRET=docker-build-secret \
  --build-arg CALENDSO_ENCRYPTION_KEY=docker-build-key-change-in-production-32bytes \
  --push \
  .
```

### Локальная сборка (без push)
```bash
docker buildx build --platform linux/amd64 \
  -f Dockerfile.root \
  -t cal-com-root-local \
  --load \
  .
```

## Образы в Registry

После успешной сборки доступны образы:
- `ghcr.io/writepavel/cal.com:root-zoho-fix-amd64`
- `ghcr.io/writepavel/cal.com:root-latest-amd64`

## Запуск

### Docker Run
```bash
docker run -d \
  --name calcom-root \
  --platform linux/amd64 \
  -e ZOHOCALENDAR_CLIENT_ID="your-client-id" \
  -e ZOHOCALENDAR_CLIENT_SECRET="your-client-secret" \
  -e DATABASE_URL="your-database-url" \
  -e NEXTAUTH_SECRET="your-secret" \
  -e CALENDSO_ENCRYPTION_KEY="your-key" \
  -e NEXT_PUBLIC_WEBAPP_URL="https://your-domain.com" \
  -p 3000:3000 \
  ghcr.io/writepavel/cal.com:root-zoho-fix-amd64
```

### Docker Compose
```yaml
version: '3.8'
services:
  calcom:
    image: ghcr.io/writepavel/cal.com:root-zoho-fix-amd64
    platform: linux/amd64
    environment:
      DATABASE_URL: ${DATABASE_URL}
      NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}
      CALENDSO_ENCRYPTION_KEY: ${CALENDSO_ENCRYPTION_KEY}
      NEXT_PUBLIC_WEBAPP_URL: ${NEXT_PUBLIC_WEBAPP_URL}
      ZOHOCALENDAR_CLIENT_ID: ${ZOHOCALENDAR_CLIENT_ID}
      ZOHOCALENDAR_CLIENT_SECRET: ${ZOHOCALENDAR_CLIENT_SECRET}
    ports:
      - "3000:3000"
    restart: unless-stopped
```

## Структура файлов

### Что копируется из корня:
```
├── package.json          ✅ Основной package.json
├── yarn.lock             ✅ Lockfile с зависимостями  
├── .yarnrc.yml           ✅ Конфигурация Yarn
├── playwright.config.ts  ✅ Настройки тестов
├── turbo.json            ✅ Конфигурация Turbo
├── i18n.json            ✅ Интернационализация
├── .yarn/               ✅ Yarn PnP файлы
├── apps/
│   ├── web/             ✅ Основное веб-приложение
│   └── api/v2/          ✅ API v2
├── packages/            ✅ Shared packages
├── tests/               ✅ Тесты
└── scripts/             ✅ Скрипты (start.sh, etc.)
```

## Включенные фиксы

### ✅ Zoho Calendar OAuth Fix
- Исправлено формирование scope параметров
- OAuth теперь работает с Zoho серверами

### ✅ Zoho Calendar Database Seeding Fix  
- Автоматическое добавление Zoho Calendar в app store
- Правильное сохранение credentials в базе данных

### ✅ Официальные скрипты
- `start.sh` - Извлечен из официального образа
- `replace-placeholder.sh` - Заменяет URL в runtime
- `wait-for-it.sh` - Ожидание готовности базы данных

## Сравнение с оригинальным Dockerfile

| Аспект | Оригинальный | Dockerfile.root |
|--------|-------------|-----------------|
| Источник файлов | `calcom/` поддиректория | Корневая директория |
| Структура контейнера | `/calcom` | `/calcom` (без изменений) |
| Скрипты | Те же | Те же (из root/scripts/) |
| Фиксы | Без фиксов | OAuth + Seeding фиксы |
| Архитектура | Зависит от платформы сборки | Явно linux/amd64 |

## Преимущества нового подхода

1. **Прямая сборка** - Нет необходимости в поддиректории `calcom/`
2. **Актуальный код** - Использует код с фиксами из корня
3. **Совместимость** - Полная совместимость с оригинальной структурой
4. **Автоматизация** - Скрипт `build-root-amd64.sh` автоматизирует процесс
5. **Linux/AMD64** - Явная поддержка серверных архитектур
6. **Docker Compose** - Готовые конфигурации для разработки и продакшена

## Требования

### Для разработки (Mac/Windows):
- Docker Desktop с buildx
- GitHub CLI (`gh`) для аутентификации
- Минимум 8GB RAM для Docker
- Свободное место: ~10GB для сборки

### Для Linux серверов:
- Docker Engine 19.03+
- 4GB RAM минимум (8GB рекомендуется)
- Свободное место: ~10GB для сборки
- **Не требуется**: Docker Desktop, buildx, GitHub CLI

> 💡 **Для Linux серверов** рекомендуется использовать упрощенный скрипт `build-linux-server.sh` - см. [LINUX_SERVER_BUILD.md](LINUX_SERVER_BUILD.md)

## Время сборки

- **Mac M1/M2**: 60-120 минут (кросс-платформенная сборка)
- **Linux AMD64**: 15-30 минут (нативная сборка)
- **Linux сервер**: 15-30 минут (рекомендуется `build-linux-server.sh`)

## Отладка

```bash
# Проверить файлы перед сборкой
ls -la package.json yarn.lock apps/ packages/ scripts/

# Очистить кеш buildx
docker buildx prune

# Проверить образ после сборки
docker buildx imagetools inspect ghcr.io/writepavel/cal.com:root-zoho-fix-amd64
```

## Миграция с calcom/ структуры

Если у вас есть существующие deployments:

1. Обновите docker-compose.yml или deployment manifest
2. Замените image на: `ghcr.io/writepavel/cal.com:root-zoho-fix-amd64`
3. Перезапустите контейнеры
4. Проверьте работу Zoho Calendar интеграции

---

*Этот образ содержит все необходимые исправления для работы Zoho Calendar с Cal.com и собран из актуального кода в корневой директории.*

**✅ Все docker-compose файлы обновлены и работают корректно с новой системой сборки Dockerfile.root!**