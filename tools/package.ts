// Builds the release zip: dist/quota_<version>.zip with a single quota_<version>/ folder
// inside, the layout the Factorio mod portal and a mods folder expect. Checks the bits the
// portal rejects (bad info.json, missing changelog/thumbnail) before zipping.
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { z } from "zod";

const root = resolve(import.meta.dir, "..");
const modDir = join(root, "mod");

const Info = z.object({
  name: z.literal("quota"),
  version: z.string().regex(/^\d+\.\d+\.\d+$/),
  title: z.string().min(1),
  author: z.string().min(1),
  factorio_version: z.string().regex(/^\d+\.\d+$/),
  description: z.string().min(1),
  dependencies: z.array(z.string()),
});

const info = Info.parse(JSON.parse(readFileSync(join(modDir, "info.json"), "utf8")));

const changelog = readFileSync(join(modDir, "changelog.txt"), "utf8");
if (!changelog.includes(`Version: ${info.version}`)) {
  throw new Error(`changelog.txt has no entry for ${info.version}`);
}
for (const f of ["thumbnail.png", "control.lua", "data.lua", "settings.lua", "scenarios/quota/control.lua"]) {
  if (!existsSync(join(modDir, f))) throw new Error(`missing mod/${f}`);
}

const folder = `quota_${info.version}`;
const dist = join(root, "dist");
const stage = join(dist, "stage");
rmSync(stage, { recursive: true, force: true });
mkdirSync(stage, { recursive: true });
cpSync(modDir, join(stage, folder), { recursive: true, dereference: true });

const zip = join(dist, `${folder}.zip`);
rmSync(zip, { force: true });
// Windows ships bsdtar, which writes zips with -a; elsewhere fall back to zip(1).
const isWin = process.platform === "win32";
const cmd = isWin
  ? [join(process.env.SystemRoot ?? "C:\\Windows", "System32", "tar.exe"), "-a", "-c", "-f", zip, "-C", stage, folder]
  : ["zip", "-qr", zip, folder];
const proc = Bun.spawnSync(cmd, { cwd: stage, stdout: "inherit", stderr: "inherit" });
if (proc.exitCode !== 0) throw new Error(`zip failed (${proc.exitCode})`);
rmSync(stage, { recursive: true, force: true });

const kb = Math.round(statSync(zip).size / 1024);
console.log(`${zip} (${kb} KB)`);
