#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const API_BASE = "https://api.meshy.ai/openapi/v1";
const TERMINAL_STATUSES = new Set(["SUCCEEDED", "FAILED", "CANCELED"]);

function usage() {
  console.log(`Meshy Smart Topology helper

Usage:
  node scripts/meshy_smart_topology.js balance [--env <path>]
  node scripts/meshy_smart_topology.js create \\
    --image <png-or-jpg> --output <directory> [--target-polycount 4000] \\
    [--texture] [--texture-image <png-or-jpg>] [--formats glb] \\
    [--env <path>] [--wait] [--dry-run]
  node scripts/meshy_smart_topology.js status \\
    --task <id> [--type image-to-3d|retexture] [--output <directory>] \\
    [--env <path>] [--wait] [--download]
  node scripts/meshy_smart_topology.js retexture \\
    --input-task <image-to-3d-id> --style-image <png-or-jpg> --output <directory> \\
    [--ai-model latest] [--texture-resolution 2k] [--formats glb] \\
    [--env <path>] [--wait] [--dry-run]

Defaults:
  - Smart Topology model: meshy-t2
  - Geometry only: should_texture=false
  - Target: 4,000 triangle faces
  - Output: GLB plus front/right/back/left previews

Run the downloaded GLB through scripts/blender/check_mesh_integrity.py before using retexture.
Retexture consumes the successful geometry task directly, so it does not regenerate topology. The
API key is read from MESHY_API_KEY, --env, or .env.local.
`);
}

function parseArgs(argv) {
  const positional = [];
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (!value.startsWith("--")) {
      positional.push(value);
      continue;
    }
    const key = value.slice(2);
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

function loadEnvFile(filePath) {
  if (!filePath) return;
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`Environment file not found: ${resolved}`);
  }
  for (const rawLine of fs.readFileSync(resolved, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match || process.env[match[1]]) continue;
    let value = match[2].trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[match[1]] = value;
  }
}

function requireApiKey(options) {
  const defaultEnv = path.resolve(__dirname, "..", ".env.local");
  if (options.env) loadEnvFile(options.env);
  else if (fs.existsSync(defaultEnv)) loadEnvFile(defaultEnv);
  const key = process.env.MESHY_API_KEY;
  if (!key) {
    throw new Error("MESHY_API_KEY is unavailable. Pass --env <path> or export it.");
  }
  return key;
}

function requireOption(options, name) {
  const value = options[name];
  if (!value || value === true) throw new Error(`Missing --${name} <value>`);
  return value;
}

function parseTargetPolycount(options) {
  const value = Number(options["target-polycount"] || 4000);
  if (!Number.isInteger(value) || value < 100 || value > 15000) {
    throw new Error("--target-polycount must be an integer from 100 through 15000 for meshy-t2.");
  }
  return value;
}

function parseFormats(options) {
  const formats = String(options.formats || "glb")
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
  const supported = new Set(["glb", "obj", "fbx", "stl", "usdz", "3mf"]);
  if (formats.length === 0 || formats.some((format) => !supported.has(format))) {
    throw new Error(`--formats must contain supported values: ${[...supported].join(", ")}`);
  }
  return [...new Set(formats)];
}

function imageMime(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".jpg" || extension === ".jpeg") return "image/jpeg";
  throw new Error(`Unsupported reference image extension: ${extension}`);
}

function imageData(filePath) {
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) throw new Error(`Reference image not found: ${resolved}`);
  const bytes = fs.readFileSync(resolved);
  return {
    resolved,
    sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    dataUri: `data:${imageMime(resolved)};base64,${bytes.toString("base64")}`,
  };
}

async function apiRequest(apiKey, endpoint, init = {}) {
  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      ...(init.headers || {}),
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
    throw new Error(`Meshy ${response.status}: ${body.message || response.statusText}`);
  }
  return body;
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function taskStatus(apiKey, taskId, taskType = "image-to-3d") {
  if (taskType !== "image-to-3d" && taskType !== "retexture") {
    throw new Error("--type must be image-to-3d or retexture.");
  }
  return apiRequest(apiKey, `/${taskType}/${encodeURIComponent(taskId)}`);
}

async function waitForTask(apiKey, taskId, taskType = "image-to-3d") {
  while (true) {
    const task = await taskStatus(apiKey, taskId, taskType);
    console.log(`${task.id}: ${task.status} ${task.progress ?? "?"}%`);
    if (TERMINAL_STATUSES.has(task.status)) return task;
    await sleep(3000);
  }
}

function ensureOutputDirectory(rawPath, allowExisting = false) {
  const output = path.resolve(rawPath);
  fs.mkdirSync(output, { recursive: true });
  if (!allowExisting && fs.existsSync(path.join(output, "task.json"))) {
    throw new Error(`Output already contains task.json: ${output}`);
  }
  return output;
}

function publicTaskRecord(task, requestRecord, files = {}) {
  return {
    id: task.id,
    type: task.type || "image-to-3d",
    status: task.status,
    progress: task.progress,
    consumed_credits: task.consumed_credits,
    created_at: task.created_at,
    started_at: task.started_at,
    finished_at: task.finished_at,
    expires_at: task.expires_at,
    task_error: task.task_error,
    request: requestRecord,
    files,
  };
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

async function downloadUrl(url, destination) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Download ${response.status}: ${response.statusText}`);
  }
  fs.writeFileSync(destination, Buffer.from(await response.arrayBuffer()));
}

async function downloadTask(task, output, requestRecord) {
  if (task.status !== "SUCCEEDED") {
    throw new Error(`Task ${task.id} is ${task.status}; outputs are unavailable.`);
  }
  const files = {};
  for (const [format, url] of Object.entries(task.model_urls || {})) {
    if (!url || format === "pre_remeshed_glb") continue;
    const destination = path.join(output, `model.${format}`);
    await downloadUrl(url, destination);
    files[format] = path.basename(destination);
    console.log(`downloaded ${format}: ${destination}`);
  }
  if (task.thumbnail_url) {
    const destination = path.join(output, "preview.png");
    await downloadUrl(task.thumbnail_url, destination);
    files.preview = path.basename(destination);
  }
  for (const [view, url] of Object.entries(task.thumbnail_urls || {})) {
    if (!url) continue;
    const destination = path.join(output, `preview_${view}.png`);
    await downloadUrl(url, destination);
    files[`preview_${view}`] = path.basename(destination);
  }
  if (task.alpha_thumbnail_url) {
    const destination = path.join(output, "preview_alpha.png");
    await downloadUrl(task.alpha_thumbnail_url, destination);
    files.preview_alpha = path.basename(destination);
  }
  writeJson(path.join(output, "task.json"), publicTaskRecord(task, requestRecord, files));
  return files;
}

async function balance(options) {
  const apiKey = requireApiKey(options);
  const result = await apiRequest(apiKey, "/balance");
  console.log(`Meshy balance: ${result.balance} credits`);
}

async function create(options) {
  const image = imageData(requireOption(options, "image"));
  const output = ensureOutputDirectory(requireOption(options, "output"));
  const targetPolycount = parseTargetPolycount(options);
  const formats = parseFormats(options);
  const shouldTexture = options.texture === true || Boolean(options["texture-image"]);
  const payload = {
    image_url: image.dataUri,
    model_type: "smart-topology",
    ai_model: "meshy-t2",
    target_polycount: targetPolycount,
    should_texture: shouldTexture,
    target_formats: formats,
    auto_size: true,
    origin_at: "bottom",
    alpha_thumbnail: true,
    multi_view_thumbnails: true,
  };
  let textureImage;
  if (options["texture-image"]) {
    textureImage = imageData(options["texture-image"]);
    payload.texture_image_url = textureImage.dataUri;
  }

  const requestRecord = {
    source_image: image.resolved,
    source_sha256: image.sha256,
    model_type: payload.model_type,
    ai_model: payload.ai_model,
    target_polycount: targetPolycount,
    should_texture: shouldTexture,
    target_formats: formats,
    auto_size: true,
    origin_at: "bottom",
    texture_image: textureImage?.resolved,
    texture_image_sha256: textureImage?.sha256,
  };
  writeJson(path.join(output, "request.json"), requestRecord);

  if (options["dry-run"]) {
    console.log(JSON.stringify({ ...payload, image_url: "[data-uri]", texture_image_url: textureImage ? "[data-uri]" : undefined }, null, 2));
    return;
  }

  const apiKey = requireApiKey(options);
  const response = await apiRequest(apiKey, "/image-to-3d", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  const taskId = response.result;
  writeJson(path.join(output, "task.json"), {
    id: taskId,
    type: "image-to-3d",
    status: "SUBMITTED",
    request: requestRecord,
    files: {},
  });
  console.log(`created Meshy Smart Topology T2 task: ${taskId}`);

  if (options.wait) {
    const task = await waitForTask(apiKey, taskId, "image-to-3d");
    writeJson(path.join(output, "task.json"), publicTaskRecord(task, requestRecord));
    if (task.status !== "SUCCEEDED") {
      throw new Error(`Task ${taskId} ended with ${task.status}: ${task.task_error?.message || "unknown error"}`);
    }
    await downloadTask(task, output, requestRecord);
  }
}

function parseTextureResolution(options) {
  const value = String(options["texture-resolution"] || "2k").toLowerCase();
  if (!new Set(["2k", "4k", "8k"]).has(value)) {
    throw new Error("--texture-resolution must be 2k, 4k, or 8k.");
  }
  return value;
}

async function retexture(options) {
  const inputTaskId = requireOption(options, "input-task");
  const styleImage = imageData(requireOption(options, "style-image"));
  const output = ensureOutputDirectory(requireOption(options, "output"));
  const formats = parseFormats(options);
  const aiModel = String(options["ai-model"] || "latest").toLowerCase();
  if (!new Set(["meshy-5", "meshy-6", "meshy-7", "latest"]).has(aiModel)) {
    throw new Error("--ai-model must be meshy-5, meshy-6, meshy-7, or latest.");
  }
  const textureResolution = parseTextureResolution(options);
  const payload = {
    input_task_id: inputTaskId,
    image_style_url: styleImage.dataUri,
    ai_model: aiModel,
    enable_original_uv: true,
    enable_pbr: false,
    texture_resolution: textureResolution,
    target_formats: formats,
    alpha_thumbnail: true,
  };
  const requestRecord = {
    input_task_id: inputTaskId,
    style_image: styleImage.resolved,
    style_image_sha256: styleImage.sha256,
    ai_model: aiModel,
    enable_original_uv: true,
    enable_pbr: false,
    texture_resolution: textureResolution,
    target_formats: formats,
  };
  writeJson(path.join(output, "request.json"), requestRecord);

  if (options["dry-run"]) {
    console.log(JSON.stringify({ ...payload, image_style_url: "[data-uri]" }, null, 2));
    return;
  }

  const apiKey = requireApiKey(options);
  const response = await apiRequest(apiKey, "/retexture", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  const taskId = response.result;
  writeJson(path.join(output, "task.json"), {
    id: taskId,
    type: "retexture",
    status: "SUBMITTED",
    request: requestRecord,
    files: {},
  });
  console.log(`created Meshy retexture task: ${taskId}`);

  if (options.wait) {
    const task = await waitForTask(apiKey, taskId, "retexture");
    writeJson(path.join(output, "task.json"), publicTaskRecord(task, requestRecord));
    if (task.status !== "SUCCEEDED") {
      throw new Error(`Task ${taskId} ended with ${task.status}: ${task.task_error?.message || "unknown error"}`);
    }
    await downloadTask(task, output, requestRecord);
  }
}

async function status(options) {
  const taskId = requireOption(options, "task");
  const apiKey = requireApiKey(options);
  const taskType = options.type || "image-to-3d";
  const task = options.wait
    ? await waitForTask(apiKey, taskId, taskType)
    : await taskStatus(apiKey, taskId, taskType);
  const output = options.output ? ensureOutputDirectory(options.output, true) : undefined;
  let requestRecord = {};
  if (output && fs.existsSync(path.join(output, "request.json"))) {
    requestRecord = JSON.parse(fs.readFileSync(path.join(output, "request.json"), "utf8"));
  }
  console.log(JSON.stringify({
    id: task.id,
    status: task.status,
    progress: task.progress,
    consumed_credits: task.consumed_credits,
    task_error: task.task_error,
    formats: Object.keys(task.model_urls || {}),
  }, null, 2));
  if (output) writeJson(path.join(output, "task.json"), publicTaskRecord(task, requestRecord));
  if (options.download) {
    if (!output) throw new Error("--download requires --output <directory>.");
    await downloadTask(task, output, requestRecord);
  }
}

async function main() {
  const { positional, options } = parseArgs(process.argv.slice(2));
  const command = positional[0];
  if (!command || options.help) {
    usage();
    return;
  }
  if (command === "balance") await balance(options);
  else if (command === "create") await create(options);
  else if (command === "retexture") await retexture(options);
  else if (command === "status") await status(options);
  else throw new Error(`Unknown command: ${command}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
