# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Running the Application
```bash
# Quick start with Docker (includes DB setup and seeding)
yarn dx

# Development server (requires manual DB setup)
yarn dev

# Development with specific services
yarn dev:api          # Web + API v2
yarn dev:console      # Web + Console
yarn dev:swagger      # API v2 + Swagger docs
```

### Database Management
```bash
# Run migrations (development)
yarn workspace @calcom/prisma db-migrate

# Run migrations (production) 
yarn workspace @calcom/prisma db-deploy

# Seed database with test data
yarn db-seed

# Open Prisma Studio for DB inspection
yarn db-studio
```

### Testing
```bash
# Unit tests (Vitest)
yarn test

# E2E tests (Playwright) - runs db-seed first
yarn test-e2e

# Run specific E2E test suite
yarn e2e:app-store    # App store tests
yarn e2e:embed        # Embed tests

# Run single test file
yarn test path/to/test.spec.ts
```

### Code Quality
```bash
# Type checking
yarn type-check

# Linting
yarn lint
yarn lint:fix

# Format code
yarn format
```

### Building
```bash
# Build for production
yarn build

# Build specific workspace
yarn workspace @calcom/web build
```

## Architecture Overview

### Monorepo Structure
Cal.com uses a Yarn workspaces monorepo with Turbo for orchestration. Key directories:

- **`/apps/web`** - Main Next.js application (App Router)
- **`/apps/api`** - API services (v1: Next.js, v2: NestJS)
- **`/packages/prisma`** - Database schema and Prisma client
- **`/packages/trpc`** - tRPC configuration and type-safe APIs
- **`/packages/lib`** - Shared utilities and business logic
- **`/packages/ui`** - Component library (Radix UI + Tailwind)
- **`/packages/features`** - Feature-specific logic and components
- **`/packages/app-store`** - 50+ integrations marketplace
- **`/packages/platform`** - Platform-specific types and components

### Key Technical Patterns

#### tRPC API Layer
All API calls use tRPC for type safety. Router definitions in `/packages/trpc/server/routers/`:
```typescript
// Example: viewer.teams.create
const createTeamHandler = async ({ ctx, input }) => {
  // Implementation
};
```

#### Database Access
Prisma ORM with single schema at `/packages/prisma/schema.prisma`. Always use transactions for multi-table operations:
```typescript
await prisma.$transaction([
  prisma.team.create(...),
  prisma.membership.create(...)
]);
```

#### Component Architecture
- UI components in `/packages/ui/components/`
- Feature components in `/packages/features/`
- Use Radix UI primitives with Tailwind styling
- Follow existing patterns for form handling (React Hook Form + Zod)

#### App Store Integrations
Each integration in `/packages/app-store/[app-name]/`:
- `metadata.ts` - App configuration
- `api/` - API handlers
- `lib/` - Integration logic
- `components/` - UI components

### Environment Configuration

Critical environment variables:
- `DATABASE_URL` - PostgreSQL connection
- `NEXTAUTH_SECRET` - Authentication secret
- `CALENDSO_ENCRYPTION_KEY` - Data encryption
- `NEXT_PUBLIC_WEBAPP_URL` - Application URL

For integrations, check `.env.example` for required credentials.

### Testing Strategy

#### Unit Tests (Vitest)
- Test files: `*.test.ts` or `*.spec.ts`
- Timeout: 500s for complex tests
- Mock Prisma with `prismock`

#### E2E Tests (Playwright)
- Test files: `*.e2e.ts`
- Projects: web, app-store, embed-core, embed-react
- Uses real database (seeded)
- Headless in CI, headed locally

### Enterprise Features
Located in `/packages/features/ee/`:
- SSO/SAML authentication
- Organizations (multi-tenant)
- Workflows automation
- Advanced analytics
- Teams management

### Performance Considerations
- Redis caching via Upstash for rate limiting
- Edge functions for optimal performance
- Database connection pooling
- Optimistic UI updates with React Query

### Security Best Practices
- All sensitive data encrypted with `CALENDSO_ENCRYPTION_KEY`
- Input validation with Zod schemas
- SQL injection prevention via Prisma
- XSS protection with DOMPurify
- Rate limiting on public endpoints

## Development Workflow

1. **Feature Development**
   - Create feature branch
   - Implement in appropriate package
   - Add tests (unit and E2E)
   - Ensure type safety

2. **Database Changes**
   - Modify `packages/prisma/schema.prisma`
   - Run `yarn workspace @calcom/prisma db-migrate`
   - Update seed data if needed

3. **API Development**
   - Add tRPC router in `/packages/trpc/server/routers/`
   - Use Zod for input validation
   - Handle errors with TRPCError

4. **UI Development**
   - Use existing UI components from `/packages/ui`
   - Follow Tailwind utility patterns
   - Ensure responsive design
   - Test with different locales

5. **Integration Development**
   - Create app in `/packages/app-store/`
   - Follow existing app patterns
   - Add to app store seed script
   - Test OAuth flow thoroughly