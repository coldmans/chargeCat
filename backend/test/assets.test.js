import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { createApp } from '../src/app.js';

function makeTempBackend() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chargecat-assets-test-'));
  const filesPath = path.join(root, 'files');
  fs.mkdirSync(filesPath, { recursive: true });
  fs.writeFileSync(path.join(filesPath, 'sleepy-cat.txt'), 'cat nap');

  const catalogPath = path.join(root, 'catalog.json');
  fs.writeFileSync(catalogPath, JSON.stringify({
    assets: [
      {
        id: 'sleepy-cat',
        title: 'Sleepy Cat',
        mediaType: 'gif',
        filename: 'sleepy-cat.txt',
        systemImage: 'moon.zzz.fill',
        soundProfile: 'silent',
        recommendedEvent: 'fullyCharged'
      }
    ]
  }));

  return {
    root,
    config: {
      port: 0,
      publicBaseUrl: null,
      assetCatalogPath: catalogPath,
      assetFilesPath: filesPath
    }
  };
}

function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      resolve(server);
    });
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
      } else {
        resolve();
      }
    });
  });
}

test('asset catalog and downloads are public', async (t) => {
  const { root, config } = makeTempBackend();
  const server = await listen(createApp(config));
  t.after(async () => {
    await close(server);
    fs.rmSync(root, { recursive: true, force: true });
  });

  const address = server.address();
  const baseURL = `http://127.0.0.1:${address.port}`;

  const healthResponse = await fetch(`${baseURL}/healthz`);
  assert.equal(healthResponse.status, 200);
  assert.deepEqual(await healthResponse.json(), {
    ok: true,
    assetCount: 1
  });

  const catalogResponse = await fetch(`${baseURL}/api/assets/catalog`);
  assert.equal(catalogResponse.status, 200);
  const catalog = await catalogResponse.json();
  assert.equal(catalog.assets.length, 1);
  assert.equal(catalog.assets[0].downloadURL, `${baseURL}/api/assets/download/sleepy-cat`);

  const downloadResponse = await fetch(catalog.assets[0].downloadURL);
  assert.equal(downloadResponse.status, 200);
  assert.equal(await downloadResponse.text(), 'cat nap');
});
