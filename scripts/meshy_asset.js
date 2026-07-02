#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const manifestPath = path.join(root, "assets", "manifest", "pets.json");
const envPath = path.join(root, ".env.local");
const apiBase = "https://api.meshy.ai/openapi/v1";

function usage() {
  console.log(`Meshy asset helper

Usage:
  node scripts/meshy_asset.js balance
  node scripts/meshy_asset.js prepare-reference <pet.key> --image <path>
  node scripts/meshy_asset.js prepare-views <pet.key> [--front <path>] [--right <path>] [--back <path>] [--left <path>] [--top <path>] [--bottom <path>]
  node scripts/meshy_asset.js make-icon <pet.key> [--image <path>] [--threshold 242] [--softness 20] [--mode edge-white|all-white]
  node scripts/meshy_asset.js register-source <pet.key> [--glb <path>] [--fbx <path>]
  node scripts/meshy_asset.js mark <pet.key> --status <concept|generated|uploaded|verified|rejected> [--notes <text>]
  node scripts/meshy_asset.js image-to-3d <pet.key> --image <path> [--wait] [--download] [--dry-run]
  node scripts/meshy_asset.js multi-image-to-3d <pet.key> [--wait] [--download] [--dry-run]
  node scripts/meshy_asset.js status <task_id> [--type image-to-3d|multi-image-to-3d] [--download <pet.key>]
  node scripts/meshy_asset.js download <pet.key> --task <task_id>

Notes:
  - Reads MESHY_API_KEY from the environment or .env.local.
  - Sends local images as data URIs, so no public URL or webhook is required.
  - Defaults to low-poly GLB/FBX with texture guided by local reference images.
  - Meshy multi-image generation currently accepts 1 to 4 images; top/bottom views are tracked for approval but not submitted.
`);
}

function loadLocalEnv() {
  if (!fs.existsSync(envPath)) return;

  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match || process.env[match[1]]) continue;

    let value = match[2];
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[match[1]] = value;
  }
}

function parseOptions(argv) {
  const positional = [];
  const options = {};

  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index];
    if (!item.startsWith("--")) {
      positional.push(item);
      continue;
    }

    const key = item.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      options[key] = true;
    } else {
      options[key] = next;
      index += 1;
    }
  }

  return { positional, options };
}

function requireApiKey() {
  loadLocalEnv();
  const apiKey = process.env.MESHY_API_KEY;
  if (!apiKey) {
    throw new Error("MESHY_API_KEY is not set. Put it in .env.local or export it in your shell.");
  }
  return apiKey;
}

function readManifest() {
  return JSON.parse(fs.readFileSync(manifestPath, "utf8"));
}

function writeManifest(manifest) {
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

function findPetEntry(manifest, key) {
  const entry = (manifest.pets || []).find((pet) => pet.key === key);
  if (!entry) {
    throw new Error(`No pet manifest entry found for ${key}`);
  }
  return entry;
}

function toRepoRelative(filePath) {
  return path.relative(root, path.resolve(filePath)).replace(/\\/g, "/");
}

function outputStem(entry) {
  return `${entry.pet}_${entry.variant}`;
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function mimeForImage(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".png") return "image/png";
  throw new Error(`Unsupported image extension ${ext}. Meshy supports .jpg, .jpeg, and .png.`);
}

function imageToDataUri(filePath) {
  const resolved = path.resolve(filePath);
  const mime = mimeForImage(resolved);
  const data = fs.readFileSync(resolved).toString("base64");
  return `data:${mime};base64,${data}`;
}

async function meshyRequest(apiKey, endpoint, options = {}) {
  const response = await fetch(`${apiBase}${endpoint}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  let body = {};
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = { message: text };
    }
  }

  if (!response.ok) {
    const message = body.message || response.statusText || "Meshy request failed";
    throw new Error(`Meshy ${response.status} ${message}`);
  }

  return body;
}

function taskEndpoint(taskType) {
  if (taskType === "multi-image-to-3d") return "/multi-image-to-3d";
  return "/image-to-3d";
}

async function getTask(apiKey, taskId, taskType = "image-to-3d") {
  return meshyRequest(apiKey, `${taskEndpoint(taskType)}/${encodeURIComponent(taskId)}`);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForTask(apiKey, taskId, taskType = "image-to-3d") {
  while (true) {
    const task = await getTask(apiKey, taskId, taskType);
    const progress = task.progress == null ? "?" : task.progress;
    console.log(`task ${task.id}: ${task.status} ${progress}%`);

    if (task.status === "SUCCEEDED" || task.status === "FAILED" || task.status === "CANCELED") {
      return task;
    }

    await sleep(5000);
  }
}

async function downloadUrl(url, destination) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Download failed ${response.status} ${response.statusText}`);
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  fs.writeFileSync(destination, buffer);
}

async function downloadTaskOutputs(task, entry, manifest) {
  if (!task.model_urls) {
    throw new Error("Task has no model_urls yet.");
  }

  const exportDir = path.join(root, "assets", "source", "pets");
  const previewDir = path.join(root, "assets", "exports", "pets");
  ensureDir(exportDir);
  ensureDir(previewDir);

  const files = entry.files || {};
  for (const format of ["glb", "fbx"]) {
    const url = task.model_urls[format];
    if (!url) continue;

    const destination = path.join(exportDir, `${outputStem(entry)}.${format}`);
    console.log(`downloading ${format} -> ${toRepoRelative(destination)}`);
    await downloadUrl(url, destination);
    files[`source_${format}`] = toRepoRelative(destination);
  }

  if (task.thumbnail_url) {
    const destination = path.join(previewDir, `${outputStem(entry)}_preview.png`);
    console.log(`downloading preview -> ${toRepoRelative(destination)}`);
    await downloadUrl(task.thumbnail_url, destination);
    files.preview_image = toRepoRelative(destination);
  }

  if (task.thumbnail_urls) {
    for (const view of ["front", "right", "back", "left"]) {
      const url = task.thumbnail_urls[view];
      if (!url) continue;

      const destination = path.join(previewDir, `${outputStem(entry)}_preview_${view}.png`);
      console.log(`downloading ${view} preview -> ${toRepoRelative(destination)}`);
      await downloadUrl(url, destination);
      files[`preview_${view}`] = toRepoRelative(destination);
    }
  }

  entry.files = files;
  entry.status = "generated";
  entry.meshy = {
    ...(entry.meshy || {}),
    task_id: task.id,
    source_url: "",
    downloaded_at: new Date().toISOString(),
    status: task.status,
    consumed_credits: task.consumed_credits,
  };

  writeManifest(manifest);
}

function prepareReference(key, imagePath) {
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  copyReferenceImage(entry, imagePath);
  writeManifest(manifest);
  console.log(`reference_image set for ${key}: ${entry.reference_image}`);
}

function prepareViews(key, options) {
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  const views = ["front", "right", "back", "left", "top", "bottom"];
  let copied = 0;

  for (const view of views) {
    const imagePath = options[view];
    if (!imagePath) continue;

    copyReferenceImage(entry, imagePath, view);
    copied += 1;
  }

  if (copied === 0) {
    throw new Error("Provide at least one view: --front, --right, --back, --left, --top, or --bottom.");
  }

  writeManifest(manifest);
  console.log(`stored ${copied} reference view(s) for ${key}`);
}

function makeIcon(key, options) {
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  const source = options.image || entry.reference_image;
  if (!source) {
    throw new Error("Provide --image <path> or set reference_image in the manifest.");
  }

  const resolvedSource = path.resolve(root, source);
  const destination = path.join(root, "assets", "exports", "pets", `${outputStem(entry)}_icon.png`);
  ensureDir(path.dirname(destination));

  const args = [
    path.join(root, "scripts", "remove_image_background.py"),
    resolvedSource,
    destination,
    "--threshold",
    String(options.threshold || 242),
    "--softness",
    String(options.softness || 20),
    "--mode",
    String(options.mode || "edge-white"),
  ];
  const result = spawnSync("python3", args, { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || "Failed to create transparent icon.");
  }

  entry.files = {
    ...(entry.files || {}),
    icon_image: toRepoRelative(destination),
  };
  writeManifest(manifest);
  console.log(`icon_image set for ${key}: ${entry.files.icon_image}`);
}

function registerSource(key, options) {
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  const files = entry.files || {};
  const sourceDir = path.join(root, "assets", "source", "pets");
  ensureDir(sourceDir);

  for (const format of ["glb", "fbx"]) {
    const source = options[format];
    if (!source) continue;

    const sourcePath = path.resolve(source);
    if (path.extname(sourcePath).toLowerCase() !== `.${format}`) {
      throw new Error(`Expected --${format} to point to a .${format} file.`);
    }

    const destination = path.join(sourceDir, `${outputStem(entry)}.${format}`);
    fs.copyFileSync(sourcePath, destination);
    files[`source_${format}`] = toRepoRelative(destination);
    console.log(`registered ${format}: ${files[`source_${format}`]}`);
  }

  if (!options.glb && !options.fbx) {
    throw new Error("Provide --glb <path> and/or --fbx <path>.");
  }

  entry.files = files;
  entry.status = "generated";
  writeManifest(manifest);
}

function markEntry(key, options) {
  const allowed = new Set(["concept", "needs_source", "generated", "uploaded", "verified", "rejected"]);
  const status = options.status;
  if (!allowed.has(status)) {
    throw new Error(`Provide --status with one of: ${[...allowed].join(", ")}`);
  }

  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  entry.status = status;
  if (options.notes) {
    const existing = entry.notes ? `${entry.notes} ` : "";
    entry.notes = `${existing}${options.notes}`.trim();
  }
  writeManifest(manifest);
  console.log(`${key} marked ${status}`);
}

function copyReferenceImage(entry, imagePath, view) {
  const sourcePath = path.resolve(imagePath);
  const ext = path.extname(sourcePath).toLowerCase();
  const destinationDir = path.join(root, "assets", "source", "references", "pets");
  const suffix = view ? `_${view}` : "";
  const destination = path.join(destinationDir, `${outputStem(entry)}${suffix}${ext}`);

  mimeForImage(sourcePath);
  ensureDir(destinationDir);
  fs.copyFileSync(sourcePath, destination);

  if (view) {
    entry.reference_images = {
      ...(entry.reference_images || {}),
      [view]: toRepoRelative(destination),
    };
    if (view === "front" || !entry.reference_image) {
      entry.reference_image = toRepoRelative(destination);
    }
  } else {
    entry.reference_image = toRepoRelative(destination);
  }
  return destination;
}

async function balance() {
  const apiKey = requireApiKey();
  const result = await meshyRequest(apiKey, "/balance", { method: "GET" });
  console.log(`Meshy balance: ${result.balance} credits`);
}

async function imageTo3d(key, options) {
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  let imagePath = options.image || entry.reference_image;
  if (!imagePath) {
    throw new Error("Provide --image <path> or set reference_image in the manifest.");
  }

  if (options.image) {
    imagePath = copyReferenceImage(entry, options.image);
  }

  const resolvedImage = path.resolve(root, imagePath);
  const imageUrl = imageToDataUri(resolvedImage);
  const targetFormats = String(options.formats || "glb,fbx")
    .split(",")
    .map((format) => format.trim())
    .filter(Boolean);

  const payload = {
    image_url: imageUrl,
    texture_image_url: imageUrl,
    model_type: "lowpoly",
    should_texture: options["no-texture"] ? false : true,
    enable_pbr: false,
    remove_lighting: true,
    target_formats: targetFormats,
    auto_size: true,
    multi_view_thumbnails: true,
    origin_at: "bottom",
  };

  if (options["texture-prompt"]) {
    payload.texture_prompt = String(options["texture-prompt"]).slice(0, 600);
    delete payload.texture_image_url;
  }

  if (options["dry-run"]) {
    console.log(JSON.stringify({ ...payload, image_url: "[data-uri]", texture_image_url: "[data-uri]" }, null, 2));
    return;
  }

  const apiKey = requireApiKey();
  const createResult = await meshyRequest(apiKey, "/image-to-3d", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  const taskId = createResult.result;
  entry.meshy = {
    ...(entry.meshy || {}),
    task_id: taskId,
    submitted_at: new Date().toISOString(),
    source_url: "",
    status: "SUBMITTED",
  };
  entry.reference_image = toRepoRelative(resolvedImage);
  writeManifest(manifest);

  console.log(`created Meshy image-to-3D task for ${key}: ${taskId}`);

  if (options.wait || options.download) {
    const task = await waitForTask(apiKey, taskId);
    if (task.status !== "SUCCEEDED") {
      throw new Error(`Task ${taskId} ended with status ${task.status}`);
    }
    if (options.download) {
      await downloadTaskOutputs(task, entry, manifest);
    }
  }
}

function multiImagePaths(entry) {
  const referenceImages = entry.reference_images || {};
  const orderedViews = ["front", "right", "back", "left"];
  const images = orderedViews.map((view) => referenceImages[view]).filter(Boolean);

  if (images.length > 0) return images;
  if (entry.reference_image) return [entry.reference_image];
  return [];
}

async function multiImageTo3d(key, options) {
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  const images = multiImagePaths(entry);
  if (images.length === 0) {
    throw new Error("No reference images found. Run prepare-views or prepare-reference first.");
  }
  if (images.length > 4) {
    throw new Error("Meshy multi-image-to-3D accepts a maximum of 4 images.");
  }

  const imageUrls = images.map((imagePath) => imageToDataUri(path.resolve(root, imagePath)));
  const targetFormats = String(options.formats || "glb,fbx")
    .split(",")
    .map((format) => format.trim())
    .filter(Boolean);

  const payload = {
    image_urls: imageUrls,
    should_texture: options["no-texture"] ? false : true,
    enable_pbr: false,
    remove_lighting: true,
    target_formats: targetFormats,
    auto_size: true,
    multi_view_thumbnails: true,
    origin_at: "bottom",
  };

  if (options["texture-prompt"]) {
    payload.texture_prompt = String(options["texture-prompt"]).slice(0, 600);
  }

  if (options["dry-run"]) {
    console.log(JSON.stringify({ ...payload, image_urls: imageUrls.map(() => "[data-uri]") }, null, 2));
    return;
  }

  const apiKey = requireApiKey();
  const createResult = await meshyRequest(apiKey, "/multi-image-to-3d", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  const taskId = createResult.result;
  entry.meshy = {
    ...(entry.meshy || {}),
    task_id: taskId,
    task_type: "multi-image-to-3d",
    submitted_at: new Date().toISOString(),
    source_url: "",
    status: "SUBMITTED",
  };
  writeManifest(manifest);

  console.log(`created Meshy multi-image-to-3D task for ${key}: ${taskId}`);

  if (options.wait || options.download) {
    const task = await waitForTask(apiKey, taskId, "multi-image-to-3d");
    if (task.status !== "SUCCEEDED") {
      throw new Error(`Task ${taskId} ended with status ${task.status}`);
    }
    if (options.download) {
      await downloadTaskOutputs(task, entry, manifest);
    }
  }
}

async function status(taskId, options) {
  const apiKey = requireApiKey();
  const taskType = options.type || "image-to-3d";
  const task = await getTask(apiKey, taskId, taskType);
  console.log(JSON.stringify({
    id: task.id,
    status: task.status,
    progress: task.progress,
    consumed_credits: task.consumed_credits,
    has_glb: Boolean(task.model_urls?.glb),
    has_fbx: Boolean(task.model_urls?.fbx),
    task_error: task.task_error,
  }, null, 2));

  if (options.download) {
    const manifest = readManifest();
    const entry = findPetEntry(manifest, options.download);
    if (task.status !== "SUCCEEDED") {
      throw new Error(`Task ${taskId} is ${task.status}; cannot download yet.`);
    }
    await downloadTaskOutputs(task, entry, manifest);
  }
}

async function download(key, taskId) {
  const apiKey = requireApiKey();
  const manifest = readManifest();
  const entry = findPetEntry(manifest, key);
  const taskType = entry.meshy?.task_type || "image-to-3d";
  const task = await getTask(apiKey, taskId, taskType);
  if (task.status !== "SUCCEEDED") {
    throw new Error(`Task ${taskId} is ${task.status}; cannot download yet.`);
  }
  await downloadTaskOutputs(task, entry, manifest);
}

async function main() {
  const { positional, options } = parseOptions(process.argv.slice(2));
  const command = positional[0];

  if (!command || options.help) {
    usage();
    return;
  }

  if (command === "balance") {
    await balance();
  } else if (command === "prepare-reference") {
    prepareReference(positional[1], options.image);
  } else if (command === "prepare-views") {
    prepareViews(positional[1], options);
  } else if (command === "make-icon") {
    makeIcon(positional[1], options);
  } else if (command === "register-source") {
    registerSource(positional[1], options);
  } else if (command === "mark") {
    markEntry(positional[1], options);
  } else if (command === "image-to-3d") {
    await imageTo3d(positional[1], options);
  } else if (command === "multi-image-to-3d") {
    await multiImageTo3d(positional[1], options);
  } else if (command === "status") {
    await status(positional[1], options);
  } else if (command === "download") {
    await download(positional[1], options.task);
  } else {
    usage();
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
