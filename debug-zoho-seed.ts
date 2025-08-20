// Debug script to check Zoho Calendar seeding
import prisma from "@calcom/prisma";

async function debugZohoCalendar() {
  console.log("\n=== Zoho Calendar Debug ===");
  
  // Check environment variables
  console.log("\n1. Environment Variables:");
  console.log("ZOHOCALENDAR_CLIENT_ID:", process.env.ZOHOCALENDAR_CLIENT_ID ? "✓ Set" : "✗ Not set");
  console.log("ZOHOCALENDAR_CLIENT_SECRET:", process.env.ZOHOCALENDAR_CLIENT_SECRET ? "✓ Set" : "✗ Not set");
  
  // Check database
  console.log("\n2. Database Check:");
  const zohoApp = await prisma.app.findUnique({
    where: { slug: "zoho-calendar" }
  });
  
  if (zohoApp) {
    console.log("Zoho Calendar app found in database ✓");
    console.log("Keys stored:", zohoApp.keys);
    console.log("Keys type:", typeof zohoApp.keys);
    
    if (zohoApp.keys && typeof zohoApp.keys === 'object') {
      const keys = zohoApp.keys as any;
      console.log("client_id present:", !!keys.client_id);
      console.log("client_secret present:", !!keys.client_secret);
    }
  } else {
    console.log("Zoho Calendar app NOT found in database ✗");
    
    // Try to seed it manually
    if (process.env.ZOHOCALENDAR_CLIENT_ID && process.env.ZOHOCALENDAR_CLIENT_SECRET) {
      console.log("\n3. Attempting to seed Zoho Calendar app...");
      
      try {
        await prisma.app.create({
          data: {
            slug: "zoho-calendar",
            dirName: "zohocalendar",
            categories: ["calendar"],
            keys: {
              client_id: process.env.ZOHOCALENDAR_CLIENT_ID,
              client_secret: process.env.ZOHOCALENDAR_CLIENT_SECRET
            },
            enabled: true
          }
        });
        console.log("✓ Zoho Calendar app seeded successfully!");
      } catch (error) {
        console.error("Failed to seed:", error);
      }
    } else {
      console.log("\n✗ Cannot seed - environment variables not set");
    }
  }
  
  // Check again after potential seeding
  const finalCheck = await prisma.app.findUnique({
    where: { slug: "zoho-calendar" }
  });
  
  console.log("\n4. Final Check:");
  console.log("App exists:", !!finalCheck);
  if (finalCheck?.keys) {
    console.log("Keys stored:", JSON.stringify(finalCheck.keys, null, 2));
  }
  
  await prisma.$disconnect();
}

debugZohoCalendar().catch(console.error);