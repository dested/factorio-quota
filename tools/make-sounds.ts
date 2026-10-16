// Synthesises QUOTA's three custom sounds into mod/sound/*.wav.
//
//   bun run tools/make-sounds.ts
//
// Everything else the mod plays is a vanilla sample (sirens, alarms, celesta
// notes from the programmable speaker). These three have no vanilla stand-in:
// a factory steam whistle for clock-in/clock-out, a cash register for payday,
// and a sad trombone for getting fired. Deterministic: same bytes every run.

import { writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";

const RATE = 44100;
const OUT = join(dirname(import.meta.dir), "mod", "sound");

// Deterministic noise so regenerating never produces a diff.
let seed = 0x2545f491;
function noise(): number {
  seed ^= seed << 13;
  seed ^= seed >>> 17;
  seed ^= seed << 5;
  return ((seed >>> 0) / 0xffffffff) * 2 - 1;
}

function buffer(seconds: number): Float64Array {
  return new Float64Array(Math.ceil(seconds * RATE));
}

function normalise(buf: Float64Array, peak: number): void {
  let max = 0;
  for (const v of buf) max = Math.max(max, Math.abs(v));
  if (max === 0) return;
  const k = peak / max;
  for (let i = 0; i < buf.length; i++) buf[i] = (buf[i] ?? 0) * k;
}

function writeWav(name: string, buf: Float64Array): void {
  const data = Buffer.alloc(buf.length * 2);
  for (let i = 0; i < buf.length; i++) {
    const v = Math.max(-1, Math.min(1, buf[i] ?? 0));
    data.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  mkdirSync(OUT, { recursive: true });
  writeFileSync(join(OUT, name), Buffer.concat([header, data]));
  console.log(`wrote ${join(OUT, name)} (${(buf.length / RATE).toFixed(2)} s)`);
}

// One-pole low-pass, used for breath noise and the trombone's "wah".
class LowPass {
  private y = 0;
  step(x: number, cutoffHz: number): number {
    const a = 1 - Math.exp((-2 * Math.PI * cutoffHz) / RATE);
    this.y += a * (x - this.y);
    return this.y;
  }
}

// ------------------------------------------------------------ whistle ---
// A three-chime steam whistle (a major triad), gliding up into pitch the way a
// real whistle does as the steam pressure builds, with a breathy hiss on top.
function whistle(): Float64Array {
  const len = 2.6;
  const buf = buffer(len);
  const chord = [392.0, 493.88, 587.33];
  const phases = chord.map(() => 0);
  const hiss = new LowPass();
  const hissHp = new LowPass();
  for (let i = 0; i < buf.length; i++) {
    const t = i / RATE;
    const env = t < 0.14 ? t / 0.14 : t > 2.05 ? Math.max(0, 1 - (t - 2.05) / 0.5) : 1;
    const glide = 0.9 + 0.1 * Math.min(1, t / 0.3);
    const vibrato = 1 + 0.004 * Math.sin(2 * Math.PI * 5.2 * t);
    let s = 0;
    chord.forEach((f, k) => {
      const ph = (phases[k] ?? 0) + (2 * Math.PI * f * glide * vibrato) / RATE;
      phases[k] = ph;
      s += Math.sin(ph) + 0.35 * Math.sin(2 * ph) + 0.12 * Math.sin(3 * ph);
    });
    const n = noise();
    const band = hiss.step(n, 4500) - hissHp.step(n, 900);
    buf[i] = env * (s / chord.length + 0.55 * band);
  }
  normalise(buf, 0.85);
  return buf;
}

// --------------------------------------------------------------- cash ---
// "Ka" (a clacky noise burst) then "ching" (two inharmonic bell strikes).
function cash(): Float64Array {
  const buf = buffer(1.1);
  const clack = new LowPass();
  const bells: Array<{ at: number; partials: number[] }> = [
    { at: 0.07, partials: [2093, 2637, 3322, 5120] },
    { at: 0.16, partials: [2349, 2960, 3729, 5700] },
  ];
  for (let i = 0; i < buf.length; i++) {
    const t = i / RATE;
    let s = 0;
    if (t < 0.06) {
      const n = noise();
      s += (n - clack.step(n, 1800)) * Math.exp(-t * 70) * 0.9;
    }
    for (const bell of bells) {
      if (t < bell.at) continue;
      const u = t - bell.at;
      bell.partials.forEach((f, k) => {
        s += (Math.sin(2 * Math.PI * f * u) * Math.exp(-u * (4 + k * 2.5))) / (1 + k * 0.6);
      });
    }
    buf[i] = s;
  }
  normalise(buf, 0.8);
  return buf;
}

// ----------------------------------------------------------- trombone ---
// Wah. Wah. Wah. Waaaaah. Band-limited sawtooth through a low-pass whose
// cutoff opens and closes on every note; the last note droops and wobbles.
function trombone(): Float64Array {
  const notes: Array<{ f: number; dur: number }> = [
    { f: 233.08, dur: 0.46 },
    { f: 220.0, dur: 0.46 },
    { f: 207.65, dur: 0.46 },
    { f: 196.0, dur: 1.9 },
  ];
  const gap = 0.06;
  const total = notes.reduce((a, n) => a + n.dur + gap, 0) + 0.3;
  const buf = buffer(total);
  const lp1 = new LowPass();
  const lp2 = new LowPass();
  let start = 0;
  let phase = 0;
  notes.forEach((note, idx) => {
    const last = idx === notes.length - 1;
    const n0 = Math.floor(start * RATE);
    const n1 = Math.floor((start + note.dur) * RATE);
    for (let i = n0; i < n1 && i < buf.length; i++) {
      const u = (i - n0) / RATE;
      const droop = last ? 1 - 0.03 * Math.min(1, u / note.dur) : 1;
      const vib = last ? 1 + 0.022 * Math.sin(2 * Math.PI * 6.3 * u) * Math.min(1, u / 0.35) : 1;
      const f = note.f * droop * vib;
      phase += (2 * Math.PI * f) / RATE;
      let saw = 0;
      for (let h = 1; h * f < 5000; h++) saw += Math.sin(h * phase) / h;
      const p = u / note.dur;
      const wah = last ? 0.35 + 0.65 * Math.sin(Math.PI * Math.min(1, p * 1.6)) : Math.sin(Math.PI * p);
      const cutoff = 260 + 1900 * Math.max(0, wah);
      const env = Math.min(1, u / 0.035) * Math.min(1, (note.dur - u) / 0.09);
      buf[i] = env * lp2.step(lp1.step(saw, cutoff), cutoff);
    }
    start += note.dur + gap;
  });
  normalise(buf, 0.85);
  return buf;
}

writeWav("whistle.wav", whistle());
writeWav("cash.wav", cash());
writeWav("trombone.wav", trombone());
