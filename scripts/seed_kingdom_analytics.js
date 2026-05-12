const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DEFAULT_COLLECTION = 'scores';
const DEFAULT_DAILY_DOCUMENT = 'kingdom_daily_score';
const DEFAULT_MONTHLY_DOCUMENT = 'kingdom_monthly_score';
const DEFAULT_DAILY_DAYS = 365;
const DEFAULT_MONTHLY_MONTHS = 120;

function parseArgs(argv) {
  const options = {
    collection: DEFAULT_COLLECTION,
    dailyDocument: DEFAULT_DAILY_DOCUMENT,
    monthlyDocument: DEFAULT_MONTHLY_DOCUMENT,
    dailyDays: DEFAULT_DAILY_DAYS,
    monthlyMonths: DEFAULT_MONTHLY_MONTHS,
    dryRun: false,
    serviceAccountPath:
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS ||
      null,
  };

  for (const arg of argv) {
    if (arg === '--dry-run') {
      options.dryRun = true;
      continue;
    }
    if (arg.startsWith('--collection=')) {
      options.collection = arg.split('=')[1];
      continue;
    }
    if (arg.startsWith('--daily-document=')) {
      options.dailyDocument = arg.split('=')[1];
      continue;
    }
    if (arg.startsWith('--monthly-document=')) {
      options.monthlyDocument = arg.split('=')[1];
      continue;
    }
    if (arg.startsWith('--daily-days=')) {
      options.dailyDays = Number.parseInt(arg.split('=')[1], 10);
      continue;
    }
    if (arg.startsWith('--monthly-months=')) {
      options.monthlyMonths = Number.parseInt(arg.split('=')[1], 10);
      continue;
    }
    if (arg.startsWith('--service-account=')) {
      options.serviceAccountPath = arg.split('=')[1];
    }
  }

  if (!options.collection) {
    throw new Error('Collection name cannot be empty.');
  }
  if (!options.dailyDocument) {
    throw new Error('Daily document name cannot be empty.');
  }
  if (!options.monthlyDocument) {
    throw new Error('Monthly document name cannot be empty.');
  }
  if (!Number.isInteger(options.dailyDays) || options.dailyDays <= 0) {
    throw new Error(`Invalid daily day count: ${options.dailyDays}`);
  }
  if (!Number.isInteger(options.monthlyMonths) || options.monthlyMonths <= 0) {
    throw new Error(`Invalid monthly month count: ${options.monthlyMonths}`);
  }

  return options;
}

function loadCredential(serviceAccountPath) {
  if (!serviceAccountPath) {
    return admin.credential.applicationDefault();
  }

  const resolvedPath = path.resolve(serviceAccountPath);
  const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  return admin.credential.cert(serviceAccount);
}

function startOfLocalDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function localDateDaysAgo(daysAgo) {
  const today = startOfLocalDay(new Date());
  return new Date(today.getFullYear(), today.getMonth(), today.getDate() - daysAgo);
}

function localMonthStartMonthsAgo(monthsAgo) {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth() - monthsAgo, 1);
}

function formatDateId(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatMonthId(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

function buildDailyTerritorySize(index, totalCount) {
  const progress = totalCount <= 1 ? 1 : index / (totalCount - 1);
  
  // Base trend + high frequency waves + random daily noise
  const trend = Math.sin(progress * Math.PI * 2.5); 
  const fluctuation1 = Math.sin(progress * Math.PI * 45); // many ups and downs
  const fluctuation2 = Math.cos(progress * Math.PI * 38);
  const noise = (Math.random() - 0.5) * 18; // random daily jumps

  const red = Math.round(600 + progress * 45 + trend * 25 + fluctuation1 * 12 + noise);
  const yellow = Math.round(600 - progress * 20 - trend * 15 + fluctuation2 * 14 - noise * 0.6);
  const blue = 1801 - red - yellow;

  return {
    red: red,
    yellow: yellow,
    blue: blue,
  };
}

function buildMonthlyTerritorySize(index, totalCount) {
  const progress = totalCount <= 1 ? 1 : index / (totalCount - 1);
  
  // Base trend + monthly fluctuations + random noise
  const trend = Math.sin(progress * Math.PI * 3.5);
  const fluctuation = Math.cos(progress * Math.PI * 18);
  const noise = (Math.random() - 0.5) * 25;

  const red = Math.round(600 + progress * 60 + trend * 30 + fluctuation * 15 + noise);
  const yellow = Math.round(600 + progress * 10 - trend * 20 + fluctuation * 12 - noise * 0.7);
  const blue = 1801 - red - yellow;

  return {
    red: red,
    yellow: yellow,
    blue: blue,
  };
}

function allocateFixedTotal(total, rawByFaction) {
  const entries = Object.entries(rawByFaction);
  const positiveEntries = entries.map(([faction, raw]) => [
    faction,
    Math.max(1, raw),
  ]);
  const rawTotal = positiveEntries.reduce((sum, [, raw]) => sum + raw, 0);
  const floorAllocations = positiveEntries.map(([faction, raw]) => {
    const exact = (raw / rawTotal) * total;
    const floored = Math.floor(exact);
    return {
      faction,
      exact,
      value: floored,
      remainder: exact - floored,
    };
  });
  let remainder = total - floorAllocations.reduce((sum, entry) => sum + entry.value, 0);
  floorAllocations.sort((a, b) => b.remainder - a.remainder);
  for (let index = 0; index < floorAllocations.length && remainder > 0; index += 1) {
    floorAllocations[index].value += 1;
    remainder -= 1;
  }
  return Object.fromEntries(
    floorAllocations.map((entry) => [entry.faction, entry.value]),
  );
}

function buildLandPowerByFaction({ territorySize, multiplier, progress }) {
  const noise = () => 1 + (Math.random() - 0.5) * 0.12; // +/- 6% random volatility

  const rawByFaction = {
    red:
      territorySize.red *
      (1 + 0.1 * Math.sin(progress * Math.PI * 15.4 + multiplier * 0.7)) * noise(),
    yellow:
      territorySize.yellow *
      (1 + 0.1 * Math.cos(progress * Math.PI * 14.8 + multiplier * 0.5)) * noise(),
    blue:
      territorySize.blue *
      (1 + 0.1 * Math.sin(progress * Math.PI * 12.1 + multiplier * 1.1)) * noise(),
  };
  return allocateFixedTotal(1801, rawByFaction);
}

function buildTributeRevenueByFaction({ territorySize, landPowerByFaction, progress }) {
  const noise = () => (Math.random() - 0.5) * 8000;

  return {
    red: Math.round(
      70000 +
        territorySize.red * 16 +
        landPowerByFaction.red * 20 +
        Math.sin(progress * Math.PI * 28 + 0.2) * 8200 + noise(),
    ),
    yellow: Math.round(
      70000 +
        territorySize.yellow * 16 +
        landPowerByFaction.yellow * 20 +
        Math.cos(progress * Math.PI * 32 + 0.5) * 8900 + noise(),
    ),
    blue: Math.round(
      70000 +
        territorySize.blue * 16 +
        landPowerByFaction.blue * 20 +
        Math.sin(progress * Math.PI * 25 + 1.0) * 7600 + noise(),
    ),
  };
}

function buildMetricDocument({
  id,
  granularity,
  territorySize,
  multiplier,
  index,
  totalCount,
}) {
  const progress = totalCount <= 1 ? 1 : index / (totalCount - 1);
  const landPowerByFaction = buildLandPowerByFaction({
    territorySize,
    multiplier,
    progress,
  });
  const tributeRevenueByFaction = buildTributeRevenueByFaction({
    territorySize,
    landPowerByFaction,
    progress,
  });

  return {
    period_id: id,
    granularity,
    red: {
      territory_size: territorySize.red,
      land_power: landPowerByFaction.red,
      tribute_revenue: tributeRevenueByFaction.red,
    },
    yellow: {
      territory_size: territorySize.yellow,
      land_power: landPowerByFaction.yellow,
      tribute_revenue: tributeRevenueByFaction.yellow,
    },
    blue: {
      territory_size: territorySize.blue,
      land_power: landPowerByFaction.blue,
      tribute_revenue: tributeRevenueByFaction.blue,
    },
    generated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function buildDailyEntries(totalDays) {
  const entries = {};
  for (let offset = totalDays - 1; offset >= 0; offset -= 1) {
    const index = totalDays - 1 - offset;
    const date = localDateDaysAgo(offset);
    const territorySize = buildDailyTerritorySize(index, totalDays);
    const id = formatDateId(date);
    entries[id] = buildMetricDocument({
      id,
      granularity: 'daily',
      territorySize,
      multiplier: 1 + index / Math.max(totalDays, 1),
      index,
      totalCount: totalDays,
    });
  }
  return entries;
}

function buildMonthlyEntries(totalMonths) {
  const entries = {};
  for (let offset = totalMonths - 1; offset >= 0; offset -= 1) {
    const index = totalMonths - 1 - offset;
    const date = localMonthStartMonthsAgo(offset);
    const territorySize = buildMonthlyTerritorySize(index, totalMonths);
    const id = formatMonthId(date);
    entries[id] = buildMetricDocument({
      id,
      granularity: 'monthly',
      territorySize,
      multiplier: 1.4 + index / Math.max(totalMonths, 1),
      index,
      totalCount: totalMonths,
    });
  }
  return entries;
}

function samplePreview(entries) {
  return Object.entries(entries)
    .slice(0, 2)
    .map(([id, data]) => ({
      id,
      red: data.red,
      yellow: data.yellow,
      blue: data.blue,
    }));
}

function buildDailyHistoryDocument(entries) {
  return {
    daily_days: Object.keys(entries).length,
    days: entries,
    generated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function buildMonthlyHistoryDocument(entries) {
  return {
    monthly_months: Object.keys(entries).length,
    months: entries,
    generated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const dailyEntries = buildDailyEntries(options.dailyDays);
  const monthlyEntries = buildMonthlyEntries(options.monthlyMonths);
  const dailyDocData = buildDailyHistoryDocument(dailyEntries);
  const monthlyDocData = buildMonthlyHistoryDocument(monthlyEntries);

  console.log(`Collection: ${options.collection}`);
  console.log(`Daily document: ${options.dailyDocument}`);
  console.log(`Monthly document: ${options.monthlyDocument}`);
  console.log(`Daily entries to write: ${Object.keys(dailyEntries).length}`);
  console.log(`Monthly entries to write: ${Object.keys(monthlyEntries).length}`);
  console.log('Daily sample:', samplePreview(dailyEntries));
  console.log('Monthly sample:', samplePreview(monthlyEntries));

  if (options.dryRun) {
    console.log('Dry run complete. No analytics data written.');
    return;
  }

  if (!options.serviceAccountPath) {
    throw new Error(
      'Missing service account path. Use --service-account=/path/to/service-account.json or set FIREBASE_SERVICE_ACCOUNT_PATH.',
    );
  }

  const credential = loadCredential(options.serviceAccountPath);
  admin.initializeApp({ credential });
  const db = admin.firestore();
  await db.collection(options.collection).doc(options.dailyDocument).set(
    dailyDocData,
    {
      merge: true,
    },
  );
  await db.collection(options.collection).doc(options.monthlyDocument).set(
    monthlyDocData,
    {
      merge: true,
    },
  );

  console.log(
    `Finished seeding "${options.collection}/${options.dailyDocument}" and "${options.collection}/${options.monthlyDocument}".`,
  );
}

main().catch((error) => {
  console.error('Failed to seed kingdom analytics:', error);
  process.exitCode = 1;
});
