import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { ChargeCatDatabase } from '../src/database.js';

function makeDatabase() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'chargecat-backend-test-'));
  const db = new ChargeCatDatabase(path.join(tempDir, 'test.sqlite'));
  return { db, tempDir };
}

test('checkout session can move from pending to ready to claimed', () => {
  const { db } = makeDatabase();
  const sessionId = '0f19744c-35ff-421c-b68f-9a67be9fdb8b';
  const installationId = 'bf354f9b-5550-4fa4-9bd5-985b7ce917db';

  const created = db.createCheckoutSession({
    id: sessionId,
    provider: 'toss',
    installationId,
    customerEmail: 'cat@example.com',
    source: 'app',
    appVersion: '1.0.1',
    expiresAt: new Date(Date.now() + 60_000).toISOString()
  });

  assert.equal(created.status, 'pending');

  const ready = db.completeCheckoutSession({
    id: sessionId,
    provider: 'toss',
    customerEmail: 'cat@example.com',
    licenseKey: '11111111-2222-4333-8444-555555555555',
    orderId: '42',
    storeId: 1,
    productId: 2,
    variantId: 3
  });

  assert.equal(ready.status, 'ready');
  assert.equal(ready.licenseKey, '11111111-2222-4333-8444-555555555555');

  const claimed = db.claimCheckoutSession({
    id: sessionId,
    installationId
  });

  assert.equal(claimed.status, 'claimed');
  assert.ok(claimed.claimedAt);
});

test('claiming with the wrong installation id returns null', () => {
  const { db } = makeDatabase();
  const sessionId = 'a91aa5ba-59e5-4a88-b727-71ab413cc4f2';

  db.createCheckoutSession({
    id: sessionId,
    provider: 'lemon',
    installationId: '05813b36-8b45-446a-8a88-d4214bd4b645',
    customerEmail: null,
    source: 'app',
    appVersion: null,
    expiresAt: new Date(Date.now() + 60_000).toISOString()
  });

  const claimed = db.claimCheckoutSession({
    id: sessionId,
    installationId: '03a92653-6d1b-4126-9c9d-71829a771bf1'
  });

  assert.equal(claimed, null);
});

test('backend-issued licenses reuse the same installation and enforce activation limits', () => {
  const { db } = makeDatabase();
  const licenseKey = 'ccp_test_license_key';

  const created = db.createLicense({
    licenseKey,
    provider: 'chargeCat',
    customerEmail: 'cat@example.com',
    activationLimit: 2,
    orderId: 'order_123'
  });

  assert.equal(created.activationLimit, 2);
  assert.equal(created.activationUsage, 0);

  const first = db.createOrReuseLicenseInstance({
    id: 'inst-1',
    licenseKey,
    installationId: '2b96afef-4b5d-4f67-b2e8-a85ca01d6ee8',
    instanceName: 'ChargeCat-Mac-inst1'
  });

  assert.equal(first.reused, false);
  assert.equal(first.license.activationUsage, 1);

  const reused = db.createOrReuseLicenseInstance({
    id: 'inst-2',
    licenseKey,
    installationId: '2b96afef-4b5d-4f67-b2e8-a85ca01d6ee8',
    instanceName: 'ChargeCat-Mac-inst1'
  });

  assert.equal(reused.reused, true);
  assert.equal(reused.instance.id, 'inst-1');
  assert.equal(reused.license.activationUsage, 1);

  const second = db.createOrReuseLicenseInstance({
    id: 'inst-3',
    licenseKey,
    installationId: '477f99ba-e0b8-4c69-a1f3-b24f7a9e11e3',
    instanceName: 'ChargeCat-Mac-inst2'
  });

  assert.equal(second.reused, false);
  assert.equal(second.license.activationUsage, 2);

  db.deactivateLicenseInstance({
    licenseKey,
    instanceId: 'inst-1'
  });

  const afterDeactivate = db.getLicense(licenseKey);
  assert.equal(afterDeactivate.activationUsage, 1);
});
