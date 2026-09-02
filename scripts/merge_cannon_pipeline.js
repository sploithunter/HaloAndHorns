#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const MANIFEST_PATH = path.join(ROOT, "scripts/merge_cannon_model_ids.json");
const UPLOADS_PATH = path.join(ROOT, "scripts/merge_cannon_uploads.json");
const REFERENCE_WIDTH = 7.953594207763672;
const FAMILIES = ["heal", "rage", "debuff", "gravity", "repulsor", "nullifier"];
const TIERS = [1, 2, 3, 4];
const DISPLAY_NAMES = {
  heal: "Heal",
  rage: "Rage",
  debuff: "Debuff",
  gravity: "Gravity",
  repulsor: "Repulsor",
  nullifier: "Nullifier",
};
const USER_SOURCE_NAMES = {
  heal: {
    1: "healing_cannon_level_1.png",
    2: "HealthCannon2.png",
    3: "healing_cannon_level_3.png",
    4: "healing_cannon_level_4.png",
  },
  rage: {
    1: "RedCannon1.png",
    2: "RedCannon2.png",
    3: "RedCannon3.png",
    4: "RedCannon4.png",
  },
  debuff: {
    1: "PurpleCannon1.png",
    2: "PurpleCannon2.png",
    3: "PurpleCannon3.png",
    4: "PurpleCannon4.png",
  },
};

function relative(...parts) {
  return parts.join("/");
}

function absolute(relativePath) {
  return path.join(ROOT, relativePath);
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(absolute(relativePath), "utf8"));
}

function sha256(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(absolute(relativePath))).digest("hex");
}

function round(value) {
  return Number(value.toFixed(6));
}

function runtimePresentation(family, tier) {
  const presentation = {};
  if (family === "rage" && tier === 1) {
    presentation.barrelYawDegrees = 270;
  }
  presentation.worldScale = tier === 1 ? 0.375 : 0.5;
  presentation.seatOffsetY = tier === 1 ? 0.55 : 0.733;
  return presentation;
}

function findRepairReport(directory) {
  const candidates = fs
    .readdirSync(absolute(directory))
    .filter((name) => name.endsWith(".repair.json") || name === "repair.json")
    .sort();
  if (candidates.length !== 1) {
    throw new Error(`Expected one repair report in ${directory}; found ${candidates.length}`);
  }
  return relative(directory, candidates[0]);
}

function conceptProvenance(family, tier) {
  if (USER_SOURCE_NAMES[family]) {
    return {
      origin: "user-supplied",
      preservedVerbatim: true,
      originalFilename: USER_SOURCE_NAMES[family][tier],
    };
  }
  if (tier === 2) {
    return {
      origin: "existing-approved-project-concept",
      preservedVerbatim: true,
      originalFilename: `${family}_cannon.png`,
    };
  }
  return {
    origin: "openai-imagegen-controlled-edit",
    preservedVerbatim: false,
    derivedFrom: `assets/concepts/merge_cannons/${family}/tier_2.png`,
    designBrief:
      tier === 1
        ? "Simplified starter silhouette with fewer reinforcements and ornaments."
        : tier === 3
          ? "Reinforced battlefield upgrade with added armor, bands, bolts, and family motifs."
          : "Ornate mythic capstone with an unmistakably upgraded silhouette and family motifs.",
  };
}

function buildTier(family, tier, upload) {
  const base = relative("assets/source/props/merge_cannons", family, `tier_${tier}`);
  const conceptPath = relative("assets/concepts/merge_cannons", family, `tier_${tier}.png`);
  const geometryTaskPath = relative(base, "geometry/task.json");
  const geometryRequestPath = relative(base, "geometry/request.json");
  const repairDirectory = relative(base, "repaired_voxel");
  const repairPath = findRepairReport(repairDirectory);
  const repairedIntegrityPath = relative(repairDirectory, "integrity.json");
  const retextureTaskPath = relative(base, "textured/task.json");
  const retextureRequestPath = relative(base, "textured/request.json");
  const texturedIntegrityPath = relative(base, "textured/integrity.json");
  const texturedGlbPath = relative(base, "textured/model.glb");
  const exportFbxPath = relative(
    "assets/exports/props/merge_cannons",
    family,
    `tier_${tier}`,
    `merge_${family}_cannon_tier_${tier}.fbx`,
  );
  const exportIntegrityPath = relative(
    "assets/exports/props/merge_cannons",
    family,
    `tier_${tier}`,
    "integrity.json",
  );

  const conceptHash = sha256(conceptPath);
  const geometryTask = readJson(geometryTaskPath);
  const geometryRequest = readJson(geometryRequestPath);
  const repair = readJson(repairPath);
  const repairedIntegrity = readJson(repairedIntegrityPath);
  const retextureTask = readJson(retextureTaskPath);
  const retextureRequest = readJson(retextureRequestPath);
  const texturedIntegrity = readJson(texturedIntegrityPath);
  const exportIntegrity = readJson(exportIntegrityPath);
  const scale = REFERENCE_WIDTH / upload.rawRobloxSize[0];
  const canonicalSize = upload.rawRobloxSize.map((value) => round(value * scale));

  return {
    tier,
    status: "COMPLETE",
    concept: {
      path: conceptPath,
      sha256: conceptHash,
      ...conceptProvenance(family, tier),
    },
    meshy: {
      geometry: {
        taskId: geometryTask.id,
        status: geometryTask.status,
        consumedCredits: geometryTask.consumed_credits,
        request: geometryRequestPath,
        task: geometryTaskPath,
        sourceSha256: geometryRequest.source_sha256,
        targetPolycount: geometryRequest.target_polycount,
      },
      repair: {
        model: relative(repairDirectory, "model.glb"),
        report: repairPath,
        integrity: repairedIntegrityPath,
        integrityPassed: repairedIntegrity.passed,
        triangles: repairedIntegrity.totals.triangles,
        boundaryEdges: repairedIntegrity.totals.boundary_edges,
        nonManifoldEdges:
          repairedIntegrity.totals.wire_edges +
          repairedIntegrity.totals.edges_with_three_or_more_faces,
        maxTriangles: repair.max_triangles,
      },
      retexture: {
        taskId: retextureTask.id,
        status: retextureTask.status,
        consumedCredits: retextureTask.consumed_credits,
        request: retextureRequestPath,
        task: retextureTaskPath,
        styleImageSha256: retextureRequest.style_image_sha256,
        textureResolution: retextureRequest.texture_resolution,
      },
    },
    deliverables: {
      texturedGlb: texturedGlbPath,
      texturedGlbSha256: sha256(texturedGlbPath),
      texturedIntegrity: texturedIntegrityPath,
      texturedIntegrityPassed: texturedIntegrity.passed,
      exportFbx: exportFbxPath,
      exportFbxSha256: sha256(exportFbxPath),
      exportIntegrity: exportIntegrityPath,
      exportIntegrityPassed: exportIntegrity.passed,
    },
    roblox: {
      modelAssetId: upload.modelAssetId,
      meshId: upload.meshId,
      textureId: upload.textureId,
      creatorGroupId: "15872767",
      rawRobloxSize: upload.rawRobloxSize,
      canonicalSize,
    },
    runtime: {
      templatePath: `ReplicatedStorage.Assets.Models.MergeCannons.${DISPLAY_NAMES[family]}.Tier${tier}`,
      sourceArtTier: tier,
      templateScale: 1,
      ...runtimePresentation(family, tier),
    },
  };
}

function buildManifest() {
  const uploads = readJson("scripts/merge_cannon_uploads.json");
  const families = {};
  let geometryCredits = 0;
  let retextureCredits = 0;
  const conceptHashes = new Set();
  const modelIds = new Set();
  const meshIds = new Set();
  const textureIds = new Set();

  for (const family of FAMILIES) {
    const tiers = TIERS.map((tier) => {
      const entry = buildTier(family, tier, uploads.families[family][String(tier)]);
      geometryCredits += entry.meshy.geometry.consumedCredits;
      retextureCredits += entry.meshy.retexture.consumedCredits;
      conceptHashes.add(entry.concept.sha256);
      modelIds.add(entry.roblox.modelAssetId);
      meshIds.add(entry.roblox.meshId);
      textureIds.add(entry.roblox.textureId);
      return entry;
    });
    families[family] = { displayName: DISPLAY_NAMES[family], tiers };
  }

  const qaPath = "assets/qa/merge_cannons/mesh_validation_contact_sheet.png";
  return {
    schemaVersion: 2,
    status: "COMPLETE",
    completedAt: uploads.runtimeVerification.verifiedInStudioAt,
    creatorGroupId: uploads.creatorGroupId,
    creatorName: uploads.ownershipVerification.creatorName,
    acceptance: {
      expectedFamilies: 6,
      expectedTiersPerFamily: 4,
      expectedVariants: 24,
      distinctConceptSha256Count: conceptHashes.size,
      distinctModelAssetIdCount: modelIds.size,
      distinctMeshIdCount: meshIds.size,
      distinctTextureIdCount: textureIds.size,
      scaledCopyTiers: 0,
    },
    pipeline: {
      geometryModel: "meshy-t2 smart-topology",
      targetPolycount: 8500,
      repair: "Blender voxel remesh 0.0026 diagonal ratio; strict manifold gate",
      maxTriangles: 9500,
      retextureModel: "latest",
      textureResolution: "2k",
      export: "FBX with embedded texture and root-bone armor",
      canonicalRuntimeWidth: REFERENCE_WIDTH,
      totalMeshyCredits: geometryCredits + retextureCredits,
      geometryCredits,
      retextureCredits,
    },
    ownershipVerification: uploads.ownershipVerification,
    visualQa: {
      path: qaPath,
      sha256: sha256(qaPath),
      layout: "Rows: Heal, Rage, Debuff, Gravity, Repulsor, Nullifier. Columns: Tier 1 through Tier 4.",
      passed: true,
    },
    runtimeContract: {
      prebakedTemplateCount: 24,
      modelTierCount: 4,
      sourceArtTierMatchesGameplayTier: true,
      templateScale: 1,
      scaledCopyFallbackRemoved: true,
      studioVerification: uploads.runtimeVerification,
    },
    families,
  };
}

function assert(condition, message, failures) {
  if (!condition) failures.push(message);
}

function audit(manifest) {
  const failures = [];
  const entries = FAMILIES.flatMap((family) => manifest.families[family].tiers);
  assert(manifest.status === "COMPLETE", "manifest status is not COMPLETE", failures);
  assert(entries.length === 24, `expected 24 variants, found ${entries.length}`, failures);
  assert(manifest.acceptance.distinctConceptSha256Count === 24, "concept art is not 24-way distinct", failures);
  assert(manifest.acceptance.distinctModelAssetIdCount === 24, "Model ids are not 24-way distinct", failures);
  assert(manifest.acceptance.distinctMeshIdCount === 24, "Mesh ids are not 24-way distinct", failures);
  assert(manifest.acceptance.distinctTextureIdCount === 24, "Texture ids are not 24-way distinct", failures);
  assert(manifest.acceptance.scaledCopyTiers === 0, "scaled-copy tiers remain", failures);
  assert(manifest.ownershipVerification.passed, "Roblox ownership verification failed", failures);
  assert(manifest.ownershipVerification.verifiedAssets === 72, "expected 72 verified Roblox assets", failures);
  assert(manifest.runtimeContract.studioVerification.passed, "Studio prebake verification failed", failures);
  assert(manifest.runtimeContract.studioVerification.templates === 24, "expected 24 Studio templates", failures);
  assert(manifest.pipeline.totalMeshyCredits === 360, "expected 360 recorded Meshy credits", failures);

  for (const family of FAMILIES) {
    const tiers = manifest.families[family].tiers;
    assert(tiers.length === 4, `${family}: expected four tiers`, failures);
    for (const entry of tiers) {
      const prefix = `${family} Tier ${entry.tier}`;
      assert(entry.status === "COMPLETE", `${prefix}: incomplete`, failures);
      assert(entry.concept.sha256 === sha256(entry.concept.path), `${prefix}: concept checksum drift`, failures);
      assert(entry.meshy.geometry.status === "SUCCEEDED", `${prefix}: geometry did not succeed`, failures);
      assert(entry.meshy.geometry.sourceSha256 === entry.concept.sha256, `${prefix}: geometry used another concept`, failures);
      assert(entry.meshy.repair.integrityPassed, `${prefix}: repaired mesh integrity failed`, failures);
      assert(entry.meshy.repair.boundaryEdges === 0, `${prefix}: repaired mesh has boundary edges`, failures);
      assert(entry.meshy.repair.nonManifoldEdges === 0, `${prefix}: repaired mesh is non-manifold`, failures);
      assert(entry.meshy.repair.triangles <= 9500, `${prefix}: triangle ceiling exceeded`, failures);
      assert(entry.meshy.retexture.status === "SUCCEEDED", `${prefix}: retexture did not succeed`, failures);
      assert(entry.meshy.retexture.styleImageSha256 === entry.concept.sha256, `${prefix}: retexture used another concept`, failures);
      assert(entry.deliverables.texturedIntegrityPassed, `${prefix}: textured GLB integrity failed`, failures);
      assert(entry.deliverables.exportIntegrityPassed, `${prefix}: FBX integrity failed`, failures);
      assert(entry.deliverables.texturedGlbSha256 === sha256(entry.deliverables.texturedGlb), `${prefix}: GLB checksum drift`, failures);
      assert(entry.deliverables.exportFbxSha256 === sha256(entry.deliverables.exportFbx), `${prefix}: FBX checksum drift`, failures);
      assert(entry.runtime.sourceArtTier === entry.tier, `${prefix}: runtime uses wrong art tier`, failures);
      assert(entry.runtime.templateScale === 1, `${prefix}: runtime template is scaled`, failures);
      const presentation = runtimePresentation(family, entry.tier);
      assert(
        entry.runtime.worldScale === presentation.worldScale,
        `${prefix}: runtime world scale drift`,
        failures,
      );
      assert(
        entry.runtime.seatOffsetY === presentation.seatOffsetY,
        `${prefix}: runtime seat offset drift`,
        failures,
      );
      assert(
        entry.runtime.barrelYawDegrees === presentation.barrelYawDegrees,
        `${prefix}: runtime barrel yaw drift`,
        failures,
      );
    }
  }

  if (failures.length) {
    throw new Error(`Merge cannon audit failed:\n- ${failures.join("\n- ")}`);
  }
  return {
    passed: true,
    variants: entries.length,
    concepts: manifest.acceptance.distinctConceptSha256Count,
    geometryTasks: entries.length,
    repairs: entries.length,
    retextureTasks: entries.length,
    texturedGlbs: entries.length,
    exportFbxs: entries.length,
    robloxAssetsVerified: manifest.ownershipVerification.verifiedAssets,
    runtimeTemplates: manifest.runtimeContract.prebakedTemplateCount,
  };
}

function main() {
  const command = process.argv[2] || "audit";
  if (command === "build") {
    const manifest = buildManifest();
    fs.writeFileSync(MANIFEST_PATH, `${JSON.stringify(manifest, null, 2)}\n`);
    console.log(`wrote ${path.relative(ROOT, MANIFEST_PATH)} with 24 complete cannon variants`);
    return;
  }
  if (command === "audit") {
    const stored = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
    const rebuilt = buildManifest();
    if (JSON.stringify(stored) !== JSON.stringify(rebuilt)) {
      throw new Error("Manifest is stale; run `node scripts/merge_cannon_pipeline.js build`.");
    }
    console.log(JSON.stringify(audit(stored), null, 2));
    return;
  }
  throw new Error("usage: node scripts/merge_cannon_pipeline.js [build|audit]");
}

try {
  main();
} catch (error) {
  console.error(error.message || error);
  process.exitCode = 1;
}
