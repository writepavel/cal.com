# Zoho Calendar Integration Fix Guide

## 🚨 Executive Summary

**Problem**: Zoho Calendar integration fails with `invalid_type in 'client_id': Required` and `invalid_type in 'client_secret': Required` errors.

**Root Cause**: Unlike other calendar integrations, Zoho Calendar is not seeded in the database during the app initialization process. The app expects to retrieve credentials from the database, but they don't exist.

**Fastest Fix**: Use [Method 1](#method-1-admin-panel-configuration-easiest) if you have admin access, or [Method 2](#method-2-environment-variables--database-seeding-recommended) for a permanent solution.

---

## 📋 Table of Contents

1. [Problem Analysis](#problem-analysis)
2. [Solution Methods](#solution-methods)
   - [Method 1: Admin Panel Configuration](#method-1-admin-panel-configuration-easiest)
   - [Method 2: Environment Variables + Database Seeding](#method-2-environment-variables--database-seeding-recommended)
   - [Method 3: Direct Database Update](#method-3-direct-database-update-via-prisma-studio)
   - [Method 4: Custom SQL Script](#method-4-custom-sql-script)
   - [Method 5: Full Code Implementation](#method-5-full-code-implementation-permanent-fix)
3. [Verification & Testing](#verification--testing)
4. [Troubleshooting](#troubleshooting)
5. [Rollback Procedures](#rollback-procedures)
6. [Long-term Solution](#long-term-solution)

---

## Problem Analysis

### Error Details
When attempting to connect Zoho Calendar, the OAuth flow fails immediately with:
```
invalid_type in 'client_id': Required
invalid_type in 'client_secret': Required
```

### Technical Root Cause

1. **Missing Database Entry**: The Zoho Calendar app exists in the codebase but is not seeded in the database
2. **Code Flow**:
   ```
   User clicks "Connect Zoho Calendar"
   → /api/integrations/zohocalendar/add
   → getAppKeysFromSlug("zohocalendar")
   → Returns empty object {} (no database entry)
   → zohoKeysSchema.parse({}) fails validation
   → Error thrown
   ```

3. **Why Other Calendars Work**: They are seeded in `/packages/prisma/seed-app-store.ts`:
   - ✅ Google Calendar (line 263)
   - ✅ Office365 Calendar (line 277)
   - ✅ Lark Calendar (line 291)
   - ❌ Zoho Calendar (MISSING)

---

## Solution Methods

### Method 1: Admin Panel Configuration (Easiest)

**Prerequisites**: Admin access to your Cal.com instance

**Steps**:

1. **Access Admin Panel**
   ```
   Navigate to: https://your-cal-instance.com/settings/admin/apps/calendar
   ```

2. **Find Zoho Calendar**
   - Look for "Zoho Calendar" in the calendar apps list
   - Click on the app card

3. **Configure App Keys**
   - Click "Configure" or "Edit Keys"
   - Enter your Zoho OAuth credentials:
     ```json
     {
       "client_id": "your_zoho_client_id_here",
       "client_secret": "your_zoho_client_secret_here"
     }
     ```

4. **Save and Enable**
   - Save the configuration
   - Ensure the app is enabled

5. **Test Connection**
   ```
   Navigate to: /settings/my-account/calendars
   Click "Connect Zoho Calendar"
   ```

---

### Method 2: Environment Variables + Database Seeding (Recommended)

**Prerequisites**: Access to server environment and ability to run database commands

**Steps**:

1. **Add Environment Variables**
   
   Create or update `.env.appStore`:
   ```bash
   # Zoho Calendar OAuth Credentials
   ZOHOCALENDAR_CLIENT_ID="your_client_id_from_zoho_api_console"
   ZOHOCALENDAR_CLIENT_SECRET="your_client_secret_from_zoho_api_console"
   ```

2. **Update Seed Script**
   
   Edit `/packages/prisma/seed-app-store.ts` (add after line 335):
   ```typescript
   // Zoho Calendar
   if (process.env.ZOHOCALENDAR_CLIENT_ID && process.env.ZOHOCALENDAR_CLIENT_SECRET) {
     await createApp("zohocalendar", "zohocalendar", ["calendar"], "zoho_calendar", {
       client_id: process.env.ZOHOCALENDAR_CLIENT_ID,
       client_secret: process.env.ZOHOCALENDAR_CLIENT_SECRET,
     });
   }
   ```

3. **Update Environment Variables List**
   
   Edit `turbo.json` (add after line 200):
   ```json
   "ZOHOCALENDAR_CLIENT_ID",
   "ZOHOCALENDAR_CLIENT_SECRET",
   ```

4. **Re-seed Database**
   ```bash
   # Clear existing app data (optional, be careful in production!)
   yarn workspace @calcom/prisma db-seed
   
   # Or if you want to preserve existing data
   yarn workspace @calcom/prisma prisma db push
   ```

5. **Restart Application**
   ```bash
   yarn dev
   # or in production
   pm2 restart cal-com
   ```

---

### Method 3: Direct Database Update via Prisma Studio

**Prerequisites**: Database access

**Steps**:

1. **Open Prisma Studio**
   ```bash
   yarn db-studio
   ```
   Browser opens at http://localhost:5555

2. **Navigate to App Table**
   - Click on "App" model
   - Search for existing "zohocalendar" entry

3. **Create or Update Entry**
   
   If entry doesn't exist, create new:
   ```json
   {
     "slug": "zohocalendar",
     "dirName": "zohocalendar",
     "categories": ["calendar"],
     "keys": {
       "client_id": "your_client_id",
       "client_secret": "your_client_secret"
     },
     "enabled": true
   }
   ```
   
   If entry exists, update the `keys` field:
   ```json
   {
     "client_id": "your_client_id",
     "client_secret": "your_client_secret"
   }
   ```

4. **Save Changes**
   - Click "Save 1 change"
   - Close Prisma Studio

---

### Method 4: Custom SQL Script

**Prerequisites**: Direct database access (PostgreSQL)

**Steps**:

1. **Check if App Exists**
   ```sql
   SELECT * FROM "App" WHERE slug = 'zohocalendar';
   ```

2. **Insert New App** (if doesn't exist)
   ```sql
   INSERT INTO "App" (
     slug, 
     "dirName", 
     categories, 
     keys, 
     enabled, 
     "createdAt", 
     "updatedAt"
   ) VALUES (
     'zohocalendar',
     'zohocalendar',
     '["calendar"]',
     '{"client_id": "YOUR_CLIENT_ID", "client_secret": "YOUR_CLIENT_SECRET"}',
     true,
     NOW(),
     NOW()
   );
   ```

3. **Update Existing App**
   ```sql
   UPDATE "App" 
   SET keys = '{"client_id": "YOUR_CLIENT_ID", "client_secret": "YOUR_CLIENT_SECRET"}'
   WHERE slug = 'zohocalendar';
   ```

4. **Verify Changes**
   ```sql
   SELECT slug, keys, enabled FROM "App" WHERE slug = 'zohocalendar';
   ```

---

### Method 5: Full Code Implementation (Permanent Fix)

**Prerequisites**: Ability to modify codebase and deploy

**Implementation Steps**:

1. **Create Migration File**
   
   Create `/packages/prisma/migrations/[timestamp]_add_zoho_calendar/migration.sql`:
   ```sql
   -- Add Zoho Calendar app if not exists
   INSERT INTO "App" (slug, "dirName", categories, keys, enabled)
   SELECT 
     'zohocalendar',
     'zohocalendar',
     '["calendar"]'::jsonb,
     '{}'::jsonb,
     true
   WHERE NOT EXISTS (
     SELECT 1 FROM "App" WHERE slug = 'zohocalendar'
   );
   ```

2. **Update Seed Script**
   
   `/packages/prisma/seed-app-store.ts`:
   ```typescript
   // Add after line 335
   // Zoho Calendar
   if (process.env.ZOHOCALENDAR_CLIENT_ID && process.env.ZOHOCALENDAR_CLIENT_SECRET) {
     await createApp("zohocalendar", "zohocalendar", ["calendar"], "zoho_calendar", {
       client_id: process.env.ZOHOCALENDAR_CLIENT_ID,
       client_secret: process.env.ZOHOCALENDAR_CLIENT_SECRET,
     });
   } else {
     // Create placeholder entry that can be configured via admin panel
     await createApp("zohocalendar", "zohocalendar", ["calendar"], "zoho_calendar", {});
   }
   ```

3. **Update Environment Examples**
   
   `/env.appStore.example`:
   ```bash
   # - ZOHOCALENDAR
   # Used for Zoho Calendar integration
   ZOHOCALENDAR_CLIENT_ID=""
   ZOHOCALENDAR_CLIENT_SECRET=""
   ```

4. **Deploy Changes**
   ```bash
   # Run migration
   yarn workspace @calcom/prisma db-deploy
   
   # Restart application
   yarn build
   yarn start
   ```

---

## Verification & Testing

### 1. Verify Database Entry
```bash
# Using Prisma Studio
yarn db-studio
# Check App table for zohocalendar entry with populated keys
```

### 2. Test OAuth Flow
1. Navigate to `/settings/my-account/calendars`
2. Click "Connect Zoho Calendar"
3. Should redirect to Zoho OAuth page (not show error)
4. Complete OAuth flow
5. Verify calendar appears in connected calendars

### 3. Test Calendar Operations
```javascript
// Test event creation
POST /api/bookings
{
  "eventTypeId": 1,
  "start": "2024-01-20T10:00:00Z",
  "end": "2024-01-20T11:00:00Z",
  "responses": {...}
}

// Verify event appears in Zoho Calendar
```

### 4. Check Multi-Datacenter Support
Test with different Zoho domains:
- US: `https://accounts.zoho.com`
- EU: `https://accounts.zoho.eu`
- IN: `https://accounts.zoho.in`
- AU: `https://accounts.zoho.com.au`

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: "App not found" error
**Solution**: Ensure the app is enabled in the database:
```sql
UPDATE "App" SET enabled = true WHERE slug = 'zohocalendar';
```

#### Issue 2: OAuth redirect mismatch
**Solution**: Verify redirect URI in Zoho API Console:
```
https://your-domain.com/api/integrations/zohocalendar/callback
```

#### Issue 3: Invalid credentials after setup
**Solution**: Check JSON formatting in keys field:
```json
{
  "client_id": "value_without_quotes_around_json",
  "client_secret": "value_without_quotes_around_json"
}
```

#### Issue 4: Multi-DC authentication fails
**Solution**: Enable "Multi-DC" option in Zoho API Console settings

#### Issue 5: Permissions error
**Solution**: Ensure OAuth scopes include:
- `ZohoCalendar.calendar.ALL`
- `ZohoCalendar.event.ALL`
- `ZohoCalendar.freebusy.READ`
- `AaaServer.profile.READ`

---

## Rollback Procedures

### If Admin Panel Method Fails
1. Navigate to admin panel
2. Remove credentials from Zoho Calendar app
3. Disable the app

### If Database Seeding Fails
```bash
# Remove the app entry
yarn workspace @calcom/prisma prisma studio
# Delete zohocalendar entry from App table

# Or via SQL
DELETE FROM "App" WHERE slug = 'zohocalendar';
```

### If Code Changes Cause Issues
```bash
# Revert changes
git checkout -- packages/prisma/seed-app-store.ts
git checkout -- turbo.json
git checkout -- .env.appStore

# Re-run original seed
yarn workspace @calcom/prisma db-seed
```

---

## Long-term Solution

### Submit Fix Upstream

1. **Fork and Clone**
   ```bash
   git clone https://github.com/calcom/cal.com.git
   cd cal.com
   git checkout -b fix/zoho-calendar-seeding
   ```

2. **Implement Changes**
   - Update `/packages/prisma/seed-app-store.ts`
   - Update `turbo.json`
   - Update `.env.appStore.example`
   - Add documentation

3. **Test Thoroughly**
   ```bash
   yarn test
   yarn test-e2e
   ```

4. **Create Pull Request**
   ```markdown
   ## Description
   Fixes Zoho Calendar integration by adding proper database seeding.
   
   ## Problem
   Zoho Calendar fails with "client_id required" error because it's not seeded in the database.
   
   ## Solution
   - Added ZOHOCALENDAR_CLIENT_ID and ZOHOCALENDAR_CLIENT_SECRET to environment variables
   - Added seeding logic to seed-app-store.ts
   - Updated documentation
   
   ## Testing
   - [x] OAuth flow works
   - [x] Calendar events sync properly
   - [x] Multi-datacenter support verified
   
   Fixes #[issue_number]
   ```

### Production Migration Script

Create a migration for existing installations:

`/packages/prisma/migrations/add_zoho_calendar_support.ts`:
```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Check if Zoho Calendar exists
  const existingApp = await prisma.app.findUnique({
    where: { slug: 'zohocalendar' }
  });

  if (!existingApp) {
    // Create with empty keys (to be configured via admin panel)
    await prisma.app.create({
      data: {
        slug: 'zohocalendar',
        dirName: 'zohocalendar',
        categories: ['calendar'],
        keys: {},
        enabled: false // Disabled by default until configured
      }
    });
    console.log('✅ Zoho Calendar app added to database');
  } else {
    console.log('ℹ️ Zoho Calendar app already exists');
  }
}

main()
  .catch((e) => {
    console.error('Migration failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

---

## Additional Resources

- [Zoho API Console](https://api-console.zoho.com/)
- [Zoho Calendar API Documentation](https://www.zoho.com/calendar/help/api/)
- [Cal.com App Store Development](https://github.com/calcom/cal.com/tree/main/packages/app-store)
- [Cal.com Self-Hosting Guide](https://cal.com/docs/self-hosting)

---

## Support

If you continue to experience issues:

1. Check Cal.com GitHub Issues: https://github.com/calcom/cal.com/issues
2. Join Cal.com Discord: https://cal.com/discord
3. Review logs:
   ```bash
   # Application logs
   pm2 logs cal-com
   
   # Database logs
   tail -f /var/log/postgresql/*.log
   ```

---

*Last updated: January 2025*
*Cal.com version: 5.6.1*