#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const manifestPath = path.join(root, "assets", "manifest", "pets.json");
const petsConfigPath = path.join(root, "configs", "pets.lua");

const args = new Set(process.argv.slice(2));
const checkMode = args.has("--check");
const jsonMode = args.has("--json");
const promptsMode = args.has("--prompts");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function isPlaceholderAssetId(value) {
  return !value || value === "rbxassetid://0" || value === "0";
}

function isRuntimeRequired(entry) {
  return ["uploaded", "verified"].includes(entry.status || "");
}

function assetNumber(value) {
  if (!value) return "";
  const match = String(value).match(/\d+/);
  return match ? match[0] : "";
}

function countChar(line, char) {
  return (line.match(new RegExp(`\\${char}`, "g")) || []).length;
}

function parsePetsConfig(filePath) {
  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  const pets = new Map();
  let inPets = false;
  let depth = 0;
  let currentPet = null;
  let currentVariant = null;
  let currentVariantsDepth = null;

  for (const rawLine of lines) {
    const line = rawLine.replace(/--.*$/, "");

    if (!inPets) {
      if (/^\s*pets\s*=\s*{/.test(line)) {
        inPets = true;
        depth += countChar(line, "{") - countChar(line, "}");
      }
      continue;
    }

    if (depth === 1) {
      const petMatch = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*{/);
      if (petMatch) {
        currentPet = petMatch[1];
      }
    } else if (depth === 2 && currentPet && /^\s*variants\s*=\s*{/.test(line)) {
      currentVariantsDepth = depth + 1;
    } else if (currentVariantsDepth && depth === currentVariantsDepth && currentPet) {
      const variantMatch = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*{/);
      if (variantMatch) {
        currentVariant = variantMatch[1];
        pets.set(`${currentPet}.${currentVariant}`, {
          key: `${currentPet}.${currentVariant}`,
          pet: currentPet,
          variant: currentVariant,
          asset_id: "",
          image_id: "",
          display_name: "",
        });
      }
    } else if (currentVariantsDepth && depth === currentVariantsDepth + 1 && currentPet && currentVariant) {
      const key = `${currentPet}.${currentVariant}`;
      const entry = pets.get(key);
      const assetMatch = line.match(/asset_id\s*=\s*"([^"]*)"/);
      const imageMatch = line.match(/image_id\s*=\s*"([^"]*)"/);
      const displayMatch = line.match(/display_name\s*=\s*"([^"]*)"/);
      if (assetMatch) entry.asset_id = assetMatch[1];
      if (imageMatch) entry.image_id = imageMatch[1];
      if (displayMatch) entry.display_name = displayMatch[1];
    }

    depth += countChar(line, "{") - countChar(line, "}");

    if (currentVariant && currentVariantsDepth && depth <= currentVariantsDepth) {
      currentVariant = null;
    }
    if (currentVariantsDepth && depth < currentVariantsDepth) {
      currentVariantsDepth = null;
    }
    if (currentPet && depth < 2) {
      currentPet = null;
    }
    if (inPets && depth <= 0) {
      break;
    }
  }

  return pets;
}

function relativeExists(relPath) {
  return Boolean(relPath) && fs.existsSync(path.join(root, relPath));
}

function analyze() {
  const manifest = readJson(manifestPath);
  const manifestPets = new Map((manifest.pets || []).map((entry) => [entry.key, entry]));
  const configPets = parsePetsConfig(petsConfigPath);

  const missingInManifest = [...configPets.keys()].filter((key) => !manifestPets.has(key)).sort();
  const missingInConfig = [...manifestPets.values()]
    .filter((entry) => isRuntimeRequired(entry) && !configPets.has(entry.key))
    .map((entry) => entry.key)
    .sort();
  const manifestOnlyAssets = [...manifestPets.values()]
    .filter((entry) => !isRuntimeRequired(entry) && !configPets.has(entry.key))
    .map((entry) => entry.key)
    .sort();

  const idMismatches = [];
  for (const [key, configEntry] of configPets) {
    const manifestEntry = manifestPets.get(key);
    if (!manifestEntry) continue;
    const manifestModelId = manifestEntry.roblox?.model_asset_id || "";
    const manifestImageId = manifestEntry.roblox?.image_asset_id || "";
    if (assetNumber(manifestModelId) !== assetNumber(configEntry.asset_id)) {
      idMismatches.push({
        key,
        field: "model_asset_id",
        manifest: manifestModelId,
        config: configEntry.asset_id,
      });
    }
    if (assetNumber(manifestImageId) !== assetNumber(configEntry.image_id)) {
      idMismatches.push({
        key,
        field: "image_asset_id",
        manifest: manifestImageId,
        config: configEntry.image_id,
      });
    }
  }

  const placeholderModelIds = [];
  const placeholderImageIds = [];
  const missingSources = [];
  const statusCounts = {};
  const modelIdUsage = new Map();

  for (const entry of manifest.pets || []) {
    statusCounts[entry.status || "unset"] = (statusCounts[entry.status || "unset"] || 0) + 1;

    const modelId = entry.roblox?.model_asset_id || "";
    if (isPlaceholderAssetId(modelId)) {
      placeholderModelIds.push(entry.key);
    } else {
      const id = assetNumber(modelId);
      modelIdUsage.set(id, [...(modelIdUsage.get(id) || []), entry.key]);
    }

    if (isPlaceholderAssetId(entry.roblox?.image_asset_id)) {
      placeholderImageIds.push(entry.key);
    }

    const sourceGlb = entry.files?.source_glb;
    const sourceFbx = entry.files?.source_fbx;
    if (!relativeExists(sourceGlb) && !relativeExists(sourceFbx)) {
      missingSources.push(entry.key);
    }
  }

  const duplicateModelIds = [...modelIdUsage.entries()]
    .map(([assetId, keys]) => {
      const unapprovedKeys = keys.filter((key) => {
        const entry = manifestPets.get(key);
        const sharedWith = entry?.roblox?.shares_model_asset_with;
        if (!sharedWith) return true;

        const sharedEntry = manifestPets.get(sharedWith);
        return !sharedEntry || assetNumber(sharedEntry.roblox?.model_asset_id) !== assetId;
      });

      return { assetId, keys, unapprovedKeys };
    })
    .filter((item) => item.keys.length > 1 && item.unapprovedKeys.length > 1);

  const errors = [
    ...missingInManifest.map((key) => `configs/pets.lua has ${key}, but the manifest does not.`),
    ...missingInConfig.map((key) => `Manifest has ${key}, but configs/pets.lua does not.`),
    ...idMismatches.map((item) => `${item.key} ${item.field} mismatch: manifest=${item.manifest || "(empty)"} config=${item.config || "(empty)"}`),
    ...placeholderModelIds
      .filter((key) => isRuntimeRequired(manifestPets.get(key)))
      .map((key) => `${key} has no Roblox model asset id.`),
    ...duplicateModelIds.map((item) => `Roblox model asset id ${item.assetId} is reused by ${item.keys.join(", ")}.`),
  ];

  const warnings = [
    ...placeholderImageIds.map((key) => `${key} has no generated image asset id yet.`),
    ...manifestOnlyAssets.map((key) => `${key} is tracked in the manifest but is not wired into configs/pets.lua yet.`),
    ...missingSources.map((key) => `${key} has no local .glb/.fbx source file yet.`),
  ];

  return {
    manifestPath: path.relative(root, manifestPath),
    petsConfigPath: path.relative(root, petsConfigPath),
    totals: {
      manifestPets: manifestPets.size,
      configPets: configPets.size,
      errors: errors.length,
      warnings: warnings.length,
    },
    statusCounts,
    missingInManifest,
    missingInConfig,
    idMismatches,
    placeholderModelIds,
    placeholderImageIds,
    missingSources,
    duplicateModelIds,
    errors,
    warnings,
    manifest,
  };
}

function printPrompts(report) {
  for (const entry of report.manifest.pets || []) {
    console.log(`## ${entry.key}`);
    console.log(entry.prompt);
    console.log("");
  }
}

function printText(report) {
  console.log("Pet Asset Pipeline Report");
  console.log("=========================");
  console.log(`Manifest: ${report.manifestPath}`);
  console.log(`Runtime config: ${report.petsConfigPath}`);
  console.log("");
  console.log(`Pets tracked: ${report.totals.manifestPets}`);
  console.log(`Pets configured: ${report.totals.configPets}`);
  console.log(`Errors: ${report.totals.errors}`);
  console.log(`Warnings: ${report.totals.warnings}`);
  console.log("");

  console.log("Status counts:");
  for (const [status, count] of Object.entries(report.statusCounts).sort()) {
    console.log(`  ${status}: ${count}`);
  }

  if (report.errors.length > 0) {
    console.log("");
    console.log("Errors:");
    for (const error of report.errors) {
      console.log(`  - ${error}`);
    }
  }

  if (report.warnings.length > 0) {
    console.log("");
    console.log("Warnings:");
    for (const warning of report.warnings.slice(0, 40)) {
      console.log(`  - ${warning}`);
    }
    if (report.warnings.length > 40) {
      console.log(`  ... ${report.warnings.length - 40} more warnings`);
    }
  }

  console.log("");
  console.log("Next useful actions:");
  console.log("  - Generate or recover source GLB/FBX files for pets marked needs_source.");
  console.log("  - After Roblox Studio import/upload, paste the Roblox asset id into both the manifest and configs/pets.lua.");
  console.log("  - Add generated thumbnail/image ids once we decide on the image pipeline.");
}

try {
  const report = analyze();
  if (jsonMode) {
    const { manifest, ...jsonReport } = report;
    console.log(JSON.stringify(jsonReport, null, 2));
  } else if (promptsMode) {
    printPrompts(report);
  } else {
    printText(report);
  }

  if (checkMode && report.errors.length > 0) {
    process.exit(1);
  }
} catch (error) {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
}
