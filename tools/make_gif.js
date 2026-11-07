const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

function decodePng(buf) {
  let offset = 8;
  let width = 0, height = 0;
  const idats = [];
  while (offset < buf.length) {
    const len = buf.readUInt32BE(offset);
    const type = buf.toString('ascii', offset + 4, offset + 8);
    const data = buf.subarray(offset + 8, offset + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
    } else if (type === 'IDAT') {
      idats.push(data);
    } else if (type === 'IEND') {
      break;
    }
    offset += 12 + len;
  }
  const uncompressed = zlib.inflateSync(Buffer.concat(idats));
  const bpp = 4;
  const stride = width * bpp;
  const raw = Buffer.alloc(width * height * 4);
  let srcPos = 0;
  for (let y = 0; y < height; y++) {
    const filter = uncompressed[srcPos++];
    for (let x = 0; x < stride; x++) {
      let b = uncompressed[srcPos++];
      const left = x >= bpp ? raw[y * stride + x - bpp] : 0;
      const up = y > 0 ? raw[(y - 1) * stride + x] : 0;
      const upLeft = (y > 0 && x >= bpp) ? raw[(y - 1) * stride + x - bpp] : 0;
      if (filter === 1) b = (b + left) & 0xff;
      else if (filter === 2) b = (b + up) & 0xff;
      else if (filter === 3) b = (b + ((left + up) >> 1)) & 0xff;
      else if (filter === 4) {
        const p = left + up - upLeft;
        const pa = Math.abs(p - left), pb = Math.abs(p - up), pc = Math.abs(p - upLeft);
        const pr = (pa <= pb && pa <= pc) ? left : (pb <= pc ? up : upLeft);
        b = (b + pr) & 0xff;
      }
      raw[y * stride + x] = b;
    }
  }
  return { width, height, raw };
}

// Median-cut color quantizer to 256 colors
function buildPalette(frames, maxColors = 256) {
  const colorMap = new Map();
  // Sample every 4th pixel for speed and balanced representation
  for (const frame of frames) {
    const raw = frame.raw;
    for (let i = 0; i < raw.length; i += 16) {
      // quantize to 5-5-5 for bucket clustering
      const r = raw[i] & 0xf8;
      const g = raw[i + 1] & 0xf8;
      const b = raw[i + 2] & 0xf8;
      const key = (r << 16) | (g << 8) | b;
      colorMap.set(key, (colorMap.get(key) || 0) + 1);
    }
  }

  let boxes = [{
    colors: Array.from(colorMap.entries()).map(([k, count]) => ({
      r: (k >> 16) & 0xff,
      g: (k >> 8) & 0xff,
      b: k & 0xff,
      count
    }))
  }];

  while (boxes.length < maxColors) {
    // Find box with greatest variance/range
    let bestBoxIdx = -1;
    let maxRange = -1;
    for (let i = 0; i < boxes.length; i++) {
      const b = boxes[i];
      if (b.colors.length <= 1) continue;
      let minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0;
      for (const c of b.colors) {
        if (c.r < minR) minR = c.r; if (c.r > maxR) maxR = c.r;
        if (c.g < minG) minG = c.g; if (c.g > maxG) maxG = c.g;
        if (c.b < minB) minB = c.b; if (c.b > maxB) maxB = c.b;
      }
      const range = Math.max(maxR - minR, maxG - minG, maxB - minB);
      if (range > maxRange) {
        maxRange = range;
        bestBoxIdx = i;
      }
    }
    if (bestBoxIdx === -1) break;

    const targetBox = boxes.splice(bestBoxIdx, 1)[0];
    let minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0;
    for (const c of targetBox.colors) {
      if (c.r < minR) minR = c.r; if (c.r > maxR) maxR = c.r;
      if (c.g < minG) minG = c.g; if (c.g > maxG) maxG = c.g;
      if (c.b < minB) minB = c.b; if (c.b > maxB) maxB = c.b;
    }
    const rRange = maxR - minR, gRange = maxG - minG, bRange = maxB - minB;
    const splitAxis = rRange >= gRange && rRange >= bRange ? 'r' : (gRange >= bRange ? 'g' : 'b');

    targetBox.colors.sort((a, b) => a[splitAxis] - b[splitAxis]);
    const mid = Math.floor(targetBox.colors.length / 2);
    boxes.push({ colors: targetBox.colors.slice(0, mid) });
    boxes.push({ colors: targetBox.colors.slice(mid) });
  }

  const palette = [];
  for (const b of boxes) {
    let totR = 0, totG = 0, totB = 0, totCount = 0;
    for (const c of b.colors) {
      totR += c.r * c.count;
      totG += c.g * c.count;
      totB += c.b * c.count;
      totCount += c.count;
    }
    if (totCount === 0) totCount = 1;
    palette.push([
      Math.round(totR / totCount),
      Math.round(totG / totCount),
      Math.round(totB / totCount)
    ]);
  }

  while (palette.length < 256) {
    palette.push([0, 0, 0]);
  }
  return palette.slice(0, 256);
}

// Build fast lookup table for RGB to palette index
function buildLookupTable(palette) {
  const lut = new Uint8Array(32 * 32 * 32);
  for (let r5 = 0; r5 < 32; r5++) {
    const r = (r5 << 3) | (r5 >> 2);
    for (let g5 = 0; g5 < 32; g5++) {
      const g = (g5 << 3) | (g5 >> 2);
      for (let b5 = 0; b5 < 32; b5++) {
        const b = (b5 << 3) | (b5 >> 2);
        let bestIdx = 0;
        let minDist = Infinity;
        for (let i = 0; i < palette.length; i++) {
          const pr = palette[i][0], pg = palette[i][1], pb = palette[i][2];
          const dist = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb);
          if (dist < minDist) {
            minDist = dist;
            bestIdx = i;
          }
        }
        lut[(r5 << 10) | (g5 << 5) | b5] = bestIdx;
      }
    }
  }
  return lut;
}

function quantizeFrame(raw, width, height, lut) {
  const out = new Uint8Array(width * height);
  for (let i = 0, p = 0; i < out.length; i++, p += 4) {
    const r5 = raw[p] >> 3;
    const g5 = raw[p + 1] >> 3;
    const b5 = raw[p + 2] >> 3;
    out[i] = lut[(r5 << 10) | (g5 << 5) | b5];
  }
  return out;
}

function encodeLZW(minCodeSize, indexedPixels) {
  const clearCode = 1 << minCodeSize;
  const eoiCode = clearCode + 1;
  let codeSize = minCodeSize + 1;
  let maxCode = 1 << codeSize;
  let nextCode = eoiCode + 1;

  const table = new Map();
  function resetTable() {
    table.clear();
    codeSize = minCodeSize + 1;
    maxCode = 1 << codeSize;
    nextCode = eoiCode + 1;
  }

  const out = [];
  let curBits = 0;
  let curVal = 0;

  function writeBits(code) {
    curVal |= (code << curBits);
    curBits += codeSize;
    while (curBits >= 8) {
      out.push(curVal & 0xff);
      curVal >>= 8;
      curBits -= 8;
    }
  }

  function flushBits() {
    while (curBits > 0) {
      out.push(curVal & 0xff);
      curVal >>= 8;
      curBits -= 8;
    }
  }

  writeBits(clearCode);
  resetTable();

  if (indexedPixels.length === 0) {
    writeBits(eoiCode);
    flushBits();
    return out;
  }

  let prefix = indexedPixels[0];
  for (let i = 1; i < indexedPixels.length; i++) {
    const k = indexedPixels[i];
    const key = (prefix << 8) | k;
    if (table.has(key)) {
      prefix = table.get(key);
    } else {
      writeBits(prefix);
      if (nextCode < 4096) {
        table.set(key, nextCode++);
        if (nextCode > maxCode && codeSize < 12) {
          codeSize++;
          maxCode = 1 << codeSize;
        }
      } else {
        writeBits(clearCode);
        resetTable();
      }
      prefix = k;
    }
  }
  writeBits(prefix);
  writeBits(eoiCode);
  flushBits();

  // Pack into sub-blocks of at most 255 bytes
  const blocks = [];
  blocks.push(minCodeSize);
  for (let i = 0; i < out.length; i += 255) {
    const chunk = out.slice(i, i + 255);
    blocks.push(chunk.length);
    for (const b of chunk) blocks.push(b);
  }
  blocks.push(0); // block terminator
  return Buffer.from(blocks);
}

function createGif(framesDir, outputPath, delayCentisec = 12) {
  console.log('Loading frames from:', framesDir);
  const files = fs.readdirSync(framesDir).filter(f => f.endsWith('.png')).sort();
  if (files.length === 0) throw new Error('No frames found');

  const decodedFrames = files.map(f => decodePng(fs.readFileSync(path.join(framesDir, f))));
  const width = decodedFrames[0].width;
  const height = decodedFrames[0].height;
  console.log(`Processing ${decodedFrames.length} frames (${width}x${height})...`);

  console.log('Building color palette...');
  const palette = buildPalette(decodedFrames, 256);
  const lut = buildLookupTable(palette);

  const buffers = [];

  // Header: GIF89a
  buffers.push(Buffer.from('GIF89a', 'ascii'));

  // Logical Screen Descriptor
  const lsd = Buffer.alloc(7);
  lsd.writeUInt16LE(width, 0);
  lsd.writeUInt16LE(height, 2);
  lsd[4] = 0xf7; // Global Color Table Flag (1), 8 bits/pixel (7), sorted (0), 256 colors (7)
  lsd[5] = 0x00; // Background color index
  lsd[6] = 0x00; // Pixel aspect ratio
  buffers.push(lsd);

  // Global Color Table (256 * 3 bytes)
  const gct = Buffer.alloc(256 * 3);
  for (let i = 0; i < 256; i++) {
    gct[i * 3] = palette[i][0];
    gct[i * 3 + 1] = palette[i][1];
    gct[i * 3 + 2] = palette[i][2];
  }
  buffers.push(gct);

  // Netscape 2.0 Application Extension (for looping)
  buffers.push(Buffer.from([0x21, 0xff, 0x0b, 0x4e, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2e, 0x30, 0x03, 0x01, 0x00, 0x00, 0x00]));

  for (let i = 0; i < decodedFrames.length; i++) {
    process.stdout.write(`Encoding frame ${i + 1}/${decodedFrames.length}...\r`);
    const qPixels = quantizeFrame(decodedFrames[i].raw, width, height, lut);

    // Graphic Control Extension
    const gce = Buffer.alloc(8);
    gce[0] = 0x21; // Extension introducer
    gce[1] = 0xf9; // Graphic control label
    gce[2] = 0x04; // Block size
    gce[3] = 0x04; // Disposal method: 1 (do not dispose)
    gce.writeUInt16LE(delayCentisec, 4); // Delay in 1/100s
    gce[6] = 0x00; // Transparent color index
    gce[7] = 0x00; // Block terminator
    buffers.push(gce);

    // Image Descriptor
    const id = Buffer.alloc(10);
    id[0] = 0x2c; // Image separator
    id.writeUInt16LE(0, 1); // Left
    id.writeUInt16LE(0, 3); // Top
    id.writeUInt16LE(width, 5); // Width
    id.writeUInt16LE(height, 7); // Height
    id[9] = 0x00; // Packed: no local color table
    buffers.push(id);

    // Image Data (LZW)
    const lzwData = encodeLZW(8, qPixels);
    buffers.push(lzwData);
  }

  // Trailer: 0x3B
  buffers.push(Buffer.from([0x3b]));

  const finalGif = Buffer.concat(buffers);
  fs.writeFileSync(outputPath, finalGif);
  console.log(`\nCreated ${outputPath} (${(finalGif.length / 1024).toFixed(1)} KB) successfully!`);
}

createGif('docs/screenshots/frames', 'docs/screenshots/gameplay.gif', 12);
