#!/usr/bin/env node
// Read-only PNG export preflight. Node built-ins only. One locale directory per run.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { inflateSync } from 'node:zlib';

const args = process.argv.slice(2);
const options = {};
let directory;
try {
  for (let i = 0; i < args.length; i++) {
    if (['--width', '--height', '--count'].includes(args[i])) {
      const key = args[i].slice(2);
      const value = Number(args[++i]);
      if (!Number.isSafeInteger(value) || value <= 0) throw Error(`Invalid ${key}`);
      options[key] = value;
    } else if (!directory && !args[i].startsWith('--')) directory = args[i];
    else throw Error(`Unexpected argument: ${args[i]}`);
  }
  if (!directory || !options.width || !options.height || !options.count) {
    throw Error('Usage: node validate-png.mjs --width N --height N --count N <locale-directory>');
  }
  const files = fs.readdirSync(directory).filter(n => /\.png$/i.test(n)).sort();
  const errors = [];
  if (files.length !== options.count) errors.push(`Expected ${options.count} PNGs, found ${files.length}`);
  const results = files.map(file => {
    const result = { file, errors: [] };
    try {
      const data = fs.readFileSync(path.join(directory, file));
      if (!data.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) throw Error('Not PNG');
      let offset = 8, header = false, ended = false, srgb = false, transparency = false, imageData = false;
      while (offset + 12 <= data.length) {
        const length = data.readUInt32BE(offset);
        if (offset + 12 + length > data.length) throw Error('Truncated PNG chunk');
        const type = data.toString('ascii', offset + 4, offset + 8);
        const body = data.subarray(offset + 8, offset + 8 + length);
        if (!header && type !== 'IHDR') throw Error('IHDR must be first');
        if (type === 'IHDR') {
          if (header || length !== 13) throw Error('Invalid IHDR');
          header = true;
          Object.assign(result, { width: body.readUInt32BE(0), height: body.readUInt32BE(4), bitDepth: body[8], colorType: body[9] });
        }
        if (type === 'sRGB' && length === 1 && body[0] <= 3) srgb = true;
        if (type === 'iCCP') {
          const end = body.indexOf(0);
          if (end < 1 || body[end + 1] !== 0) throw Error('Invalid ICC metadata');
          const profile = inflateSync(body.subarray(end + 2), { maxOutputLength: 16 * 1024 * 1024 });
          if (/sRGB/i.test(profile.toString('latin1').replaceAll('\0', ''))) srgb = true;
        }
        if (type === 'tRNS') transparency = true;
        if (type === 'IDAT') imageData = true;
        offset += 12 + length;
        if (type === 'IEND') { ended = true; break; }
      }
      if (!header || !ended || !imageData) throw Error('Incomplete PNG');
      if (result.width !== options.width || result.height !== options.height) result.errors.push('Wrong dimensions');
      if (result.bitDepth !== 8 || result.colorType !== 2 || transparency) result.errors.push('Expected 8-bit RGB without transparency');
      if (!srgb) result.errors.push('No recognizable sRGB metadata; inspect/export profile explicitly');
      result.srgbMetadata = srgb;
      result.sha256 = createHash('sha256').update(data).digest('hex');
    } catch (error) { result.errors.push(error.message); }
    return result;
  });
  const pass = errors.length === 0 && results.every(r => r.errors.length === 0);
  console.log(JSON.stringify({ pass, directory: path.resolve(directory), expected: options, errors, results,
    scope: 'Metadata preflight only; not full pixel decoding, ICC conformance, visual review or App Store approval.' }, null, 2));
  process.exitCode = pass ? 0 : 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 2;
}
