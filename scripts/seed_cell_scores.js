const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DEFAULT_RADIUS = 24;
const DEFAULT_COLLECTION = 'scores';
const DEFAULT_DOCUMENT = 'cell_scores';
const FACTIONS = ['red', 'yellow', 'blue'];

function parseArgs(argv) {
  const options = {
    radius: DEFAULT_RADIUS,
    collection: DEFAULT_COLLECTION,
    document: DEFAULT_DOCUMENT,
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
    if (arg.startsWith('--radius=')) {
      options.radius = Number.parseInt(arg.split('=')[1], 10);
      continue;
    }
    if (arg.startsWith('--collection=')) {
      options.collection = arg.split('=')[1];
      continue;
    }
    if (arg.startsWith('--document=')) {
      options.document = arg.split('=')[1];
      continue;
    }
    if (arg.startsWith('--service-account=')) {
      options.serviceAccountPath = arg.split('=')[1];
    }
  }

  if (!Number.isInteger(options.radius) || options.radius < 0) {
    throw new Error(`Invalid radius: ${options.radius}`);
  }
  if (!options.collection) {
    throw new Error('Collection name cannot be empty.');
  }
  if (!options.document) {
    throw new Error('Document name cannot be empty.');
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

function scoresForOwner(owner, ownerScore = 100, nonOwnerScore = 50) {
  return {
    red_score: owner === 'red' ? ownerScore : nonOwnerScore,
    yellow_score: owner === 'yellow' ? ownerScore : nonOwnerScore,
    blue_score: owner === 'blue' ? ownerScore : nonOwnerScore,
  };
}

function normalizeDegrees(angleRadians) {
  const degrees = (angleRadians * 180) / Math.PI;
  return (degrees + 360) % 360;
}

function circularDistanceDegrees(a, b) {
  const diff = Math.abs(a - b) % 360;
  return Math.min(diff, 360 - diff);
}

function specialLevelFiveCorners(radius) {
  return [
    { q: radius, r: 0, owner: 'red' },
    { q: -radius, r: radius, owner: 'yellow' },
    { q: 0, r: -radius, owner: 'blue' },
  ];
}

function applySpecialLevelFiveCorners(cells, radius) {
  const specialCorners = specialLevelFiveCorners(radius);

  for (const special of specialCorners) {
    const targetCell = cells.find(
      (cell) => cell.q === special.q && cell.r === special.r,
    );
    if (!targetCell) {
      throw new Error(
        `Missing special level-5 corner at (${special.q}, ${special.r}).`,
      );
    }
    targetCell.owner = special.owner;
    targetCell.data = scoresForOwner(special.owner, -1, 0);
  }
}

function buildCells(radius) {
  const cells = [];
  const remainingCells = [];
  const sectorCenters = {
    red: 30,
    yellow: 150,
    blue: 270,
  };
  const specialCorners = specialLevelFiveCorners(radius);
  const specialCornerById = new Map(
    specialCorners.map((corner) => [`${corner.q}_${corner.r}`, corner]),
  );

  for (let q = -radius; q <= radius; q += 1) {
    const rMin = Math.max(-radius, -q - radius);
    const rMax = Math.min(radius, -q + radius);
    for (let r = rMin; r <= rMax; r += 1) {
      const id = `${q}_${r}`;
      if (q === 0 && r === 0) {
        cells.push({
          id,
          q,
          r,
          owner: 'red',
          data: scoresForOwner('red'),
        });
        continue;
      }

      const specialCorner = specialCornerById.get(id);
      if (specialCorner) {
        cells.push({
          id,
          q,
          r,
          owner: specialCorner.owner,
          data: scoresForOwner(specialCorner.owner, -1, 0),
        });
        continue;
      }

      const localX = 1.5 * q;
      const localY = Math.sqrt(3) * (r + q / 2);
      const angleDegrees = normalizeDegrees(Math.atan2(localY, localX));
      const preferences = FACTIONS.map((faction) => ({
        faction,
        distance: circularDistanceDegrees(angleDegrees, sectorCenters[faction]),
      })).sort((a, b) => a.distance - b.distance);
      remainingCells.push({
        id,
        q,
        r,
        preferences: preferences.map((entry) => entry.faction),
        priority: (preferences[1]?.distance ?? 180) - preferences[0].distance,
      });
    }
  }

  const targetPerFaction = remainingCells.length / FACTIONS.length;
  if (!Number.isInteger(targetPerFaction)) {
    throw new Error(
      `Remaining cell count ${remainingCells.length} is not divisible equally across ${FACTIONS.length} factions.`,
    );
  }

  const remainingQuota = Object.fromEntries(
    FACTIONS.map((faction) => [faction, targetPerFaction]),
  );

  remainingCells.sort((a, b) => b.priority - a.priority);

  for (const cell of remainingCells) {
    const owner =
      cell.preferences.find((faction) => remainingQuota[faction] > 0) ??
      cell.preferences[0];
    remainingQuota[owner] -= 1;
    cells.push({
      id: cell.id,
      q: cell.q,
      r: cell.r,
      owner,
      data: scoresForOwner(owner),
    });
  }

  return cells;
}

function flattenCells(cells) {
  const flattened = {};
  for (const cell of cells) {
    for (const [scoreName, value] of Object.entries(cell.data)) {
      flattened[`${cell.id}_${scoreName}`] = value;
    }
  }
  return flattened;
}

async function writeCells(db, collectionName, documentName, flattenedFields) {
  const docRef = db.collection(collectionName).doc(documentName);
  await docRef.set(flattenedFields);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const cells = buildCells(options.radius);
  const flattenedFields = flattenCells(cells);
  const counts = cells.reduce(
    (acc, cell) => {
      acc[cell.owner] += 1;
      return acc;
    },
    { red: 0, yellow: 0, blue: 0 },
  );

  console.log(`Collection: ${options.collection}`);
  console.log(`Document: ${options.document}`);
  console.log(`Radius: ${options.radius}`);
  console.log(`Total cells: ${cells.length}`);
  console.log(
    `Owner split: red=${counts.red}, yellow=${counts.yellow}, blue=${counts.blue}`,
  );
  console.log(`Flattened field count: ${Object.keys(flattenedFields).length}`);
  console.log(
    'Sample fields:',
    Object.entries(flattenedFields)
      .slice(0, 9)
      .map(([key, value]) => ({ [key]: value })),
  );

  if (options.dryRun) {
    console.log('Dry run complete. No data written.');
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
  await writeCells(db, options.collection, options.document, flattenedFields);
  console.log(
    `Finished seeding 1 document into "${options.collection}/${options.document}".`,
  );
}

main().catch((error) => {
  console.error('Failed to seed cell_scores:', error);
  process.exitCode = 1;
});
