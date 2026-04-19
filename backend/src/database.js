import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

function isoNow() {
  return new Date().toISOString();
}

function mapSession(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    provider: row.provider,
    installationId: row.installation_id,
    customerEmail: row.customer_email,
    source: row.source,
    appVersion: row.app_version,
    status: row.status,
    checkoutId: row.checkout_id ?? row.lemon_checkout_id,
    checkoutUrl: row.checkout_url ?? row.lemon_checkout_url,
    licenseKey: row.license_key,
    orderId: row.order_id,
    orderIdentifier: row.order_identifier,
    orderAmount: row.order_amount,
    orderCurrency: row.order_currency,
    paymentKey: row.payment_key,
    paymentMethod: row.payment_method,
    paymentStatus: row.payment_status,
    storeId: row.store_id,
    productId: row.product_id,
    variantId: row.variant_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    expiresAt: row.expires_at,
    completedAt: row.completed_at,
    claimedAt: row.claimed_at,
    lastError: row.last_error
  };
}

function mapLicense(row, activationUsage = 0) {
  if (!row) {
    return null;
  }

  return {
    key: row.license_key,
    provider: row.provider,
    customerEmail: row.customer_email,
    status: row.status,
    activationLimit: row.activation_limit,
    activationUsage,
    orderId: row.order_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function mapLicenseInstance(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    licenseKey: row.license_key,
    installationId: row.installation_id,
    name: row.instance_name,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deactivatedAt: row.deactivated_at,
    lastValidatedAt: row.last_validated_at
  };
}

export class ChargeCatDatabase {
  constructor(databasePath) {
    fs.mkdirSync(path.dirname(databasePath), { recursive: true });
    this.db = new DatabaseSync(databasePath);
    this.db.exec('PRAGMA journal_mode = WAL;');
    this.db.exec('PRAGMA foreign_keys = ON;');
    this.createSchema();
  }

  createSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS checkout_sessions (
        id TEXT PRIMARY KEY,
        installation_id TEXT NOT NULL,
        customer_email TEXT,
        source TEXT NOT NULL,
        app_version TEXT,
        status TEXT NOT NULL,
        lemon_checkout_id TEXT,
        lemon_checkout_url TEXT,
        license_key TEXT,
        order_id TEXT,
        order_identifier TEXT,
        store_id INTEGER,
        product_id INTEGER,
        variant_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        completed_at TEXT,
        claimed_at TEXT,
        last_error TEXT
      ) STRICT;

      CREATE INDEX IF NOT EXISTS idx_checkout_sessions_installation
      ON checkout_sessions (installation_id);

      CREATE INDEX IF NOT EXISTS idx_checkout_sessions_status
      ON checkout_sessions (status);

      CREATE TABLE IF NOT EXISTS webhook_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_name TEXT NOT NULL,
        resource_type TEXT,
        resource_id TEXT,
        status TEXT NOT NULL,
        error_message TEXT,
        payload_json TEXT NOT NULL,
        received_at TEXT NOT NULL,
        processed_at TEXT
      ) STRICT;

      CREATE TABLE IF NOT EXISTS licenses (
        license_key TEXT PRIMARY KEY,
        provider TEXT NOT NULL,
        customer_email TEXT,
        status TEXT NOT NULL,
        activation_limit INTEGER NOT NULL,
        order_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      ) STRICT;

      CREATE TABLE IF NOT EXISTS license_instances (
        id TEXT PRIMARY KEY,
        license_key TEXT NOT NULL,
        installation_id TEXT NOT NULL,
        instance_name TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deactivated_at TEXT,
        last_validated_at TEXT,
        FOREIGN KEY (license_key) REFERENCES licenses(license_key) ON DELETE CASCADE
      ) STRICT;

      CREATE INDEX IF NOT EXISTS idx_license_instances_license_key
      ON license_instances (license_key);

      CREATE INDEX IF NOT EXISTS idx_license_instances_installation
      ON license_instances (installation_id);
    `);

    this.ensureCheckoutSessionColumns();
  }

  ensureCheckoutSessionColumns() {
    const columns = new Set(
      this.db.prepare(`PRAGMA table_info(checkout_sessions)`).all().map((column) => column.name)
    );

    const requiredColumns = {
      provider: "TEXT NOT NULL DEFAULT 'lemon'",
      checkout_id: 'TEXT',
      checkout_url: 'TEXT',
      order_amount: 'INTEGER',
      order_currency: "TEXT DEFAULT 'KRW'",
      payment_key: 'TEXT',
      payment_method: 'TEXT',
      payment_status: 'TEXT'
    };

    for (const [name, definition] of Object.entries(requiredColumns)) {
      if (!columns.has(name)) {
        this.db.exec(`ALTER TABLE checkout_sessions ADD COLUMN ${name} ${definition}`);
      }
    }
  }

  createCheckoutSession({ id, provider, installationId, customerEmail, source, appVersion, expiresAt }) {
    const now = isoNow();
    this.db.prepare(`
      INSERT INTO checkout_sessions (
        id,
        provider,
        installation_id,
        customer_email,
        source,
        app_version,
        status,
        created_at,
        updated_at,
        expires_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)
    `).run(
      id,
      provider,
      installationId,
      customerEmail ?? null,
      source,
      appVersion ?? null,
      now,
      now,
      expiresAt
    );

    return this.getCheckoutSession(id);
  }

  getCheckoutSession(id) {
    const row = this.db.prepare(`
      SELECT *
      FROM checkout_sessions
      WHERE id = ?
      LIMIT 1
    `).get(id);

    return mapSession(row);
  }

  getCheckoutSessionByOrderId(orderId) {
    const row = this.db.prepare(`
      SELECT *
      FROM checkout_sessions
      WHERE order_id = ?
      LIMIT 1
    `).get(orderId);

    return mapSession(row);
  }

  attachCheckout({
    id,
    provider,
    checkoutId,
    checkoutUrl,
    orderId,
    orderAmount,
    orderCurrency
  }) {
    this.db.prepare(`
      UPDATE checkout_sessions
      SET provider = ?,
          checkout_id = COALESCE(?, checkout_id),
          checkout_url = COALESCE(?, checkout_url),
          lemon_checkout_id = COALESCE(?, lemon_checkout_id),
          lemon_checkout_url = COALESCE(?, lemon_checkout_url),
          order_id = COALESCE(?, order_id),
          order_amount = COALESCE(?, order_amount),
          order_currency = COALESCE(?, order_currency),
          updated_at = ?
      WHERE id = ?
    `).run(
      provider,
      checkoutId ?? null,
      checkoutUrl ?? null,
      provider === 'lemon' ? checkoutId ?? null : null,
      provider === 'lemon' ? checkoutUrl ?? null : null,
      orderId ?? null,
      orderAmount ?? null,
      orderCurrency ?? null,
      isoNow(),
      id
    );

    return this.getCheckoutSession(id);
  }

  recordOrderCreated({ id, orderId, orderIdentifier, customerEmail }) {
    this.db.prepare(`
      UPDATE checkout_sessions
      SET order_id = COALESCE(?, order_id),
          order_identifier = COALESCE(?, order_identifier),
          customer_email = COALESCE(?, customer_email),
          updated_at = ?
      WHERE id = ?
    `).run(
      orderId ?? null,
      orderIdentifier ?? null,
      customerEmail ?? null,
      isoNow(),
      id
    );

    return this.getCheckoutSession(id);
  }

  completeCheckoutSession({
    id,
    provider,
    customerEmail,
    licenseKey,
    orderId,
    storeId,
    productId,
    variantId,
    paymentKey,
    paymentMethod,
    paymentStatus
  }) {
    const now = isoNow();

    this.db.prepare(`
      UPDATE checkout_sessions
      SET provider = COALESCE(?, provider),
          status = 'ready',
          customer_email = COALESCE(?, customer_email),
          license_key = ?,
          order_id = COALESCE(?, order_id),
          store_id = COALESCE(?, store_id),
          product_id = COALESCE(?, product_id),
          variant_id = COALESCE(?, variant_id),
          payment_key = COALESCE(?, payment_key),
          payment_method = COALESCE(?, payment_method),
          payment_status = COALESCE(?, payment_status),
          completed_at = ?,
          updated_at = ?,
          last_error = NULL
      WHERE id = ?
    `).run(
      provider ?? null,
      customerEmail ?? null,
      licenseKey,
      orderId ?? null,
      storeId ?? null,
      productId ?? null,
      variantId ?? null,
      paymentKey ?? null,
      paymentMethod ?? null,
      paymentStatus ?? null,
      now,
      now,
      id
    );

    return this.getCheckoutSession(id);
  }

  updateCheckoutPaymentState({ id, paymentKey, paymentMethod, paymentStatus, errorMessage }) {
    this.db.prepare(`
      UPDATE checkout_sessions
      SET payment_key = COALESCE(?, payment_key),
          payment_method = COALESCE(?, payment_method),
          payment_status = COALESCE(?, payment_status),
          last_error = ?,
          updated_at = ?
      WHERE id = ?
    `).run(
      paymentKey ?? null,
      paymentMethod ?? null,
      paymentStatus ?? null,
      errorMessage ?? null,
      isoNow(),
      id
    );

    return this.getCheckoutSession(id);
  }

  markCheckoutFailed({ id, errorMessage }) {
    this.db.prepare(`
      UPDATE checkout_sessions
      SET status = 'failed',
          last_error = ?,
          updated_at = ?
      WHERE id = ?
    `).run(
      errorMessage,
      isoNow(),
      id
    );

    return this.getCheckoutSession(id);
  }

  markCheckoutExpired(id) {
    this.db.prepare(`
      UPDATE checkout_sessions
      SET status = 'expired',
          updated_at = ?
      WHERE id = ?
        AND status = 'pending'
    `).run(
      isoNow(),
      id
    );

    return this.getCheckoutSession(id);
  }

  claimCheckoutSession({ id, installationId }) {
    const session = this.getCheckoutSession(id);
    if (!session || session.installationId !== installationId) {
      return null;
    }

    if (session.claimedAt) {
      return session;
    }

    this.db.prepare(`
      UPDATE checkout_sessions
      SET status = 'claimed',
          claimed_at = ?,
          updated_at = ?
      WHERE id = ?
    `).run(
      isoNow(),
      isoNow(),
      id
    );

    return this.getCheckoutSession(id);
  }

  createLicense({ licenseKey, provider, customerEmail, activationLimit, orderId }) {
    const now = isoNow();
    this.db.prepare(`
      INSERT OR IGNORE INTO licenses (
        license_key,
        provider,
        customer_email,
        status,
        activation_limit,
        order_id,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, 'active', ?, ?, ?, ?)
    `).run(
      licenseKey,
      provider,
      customerEmail ?? null,
      activationLimit,
      orderId ?? null,
      now,
      now
    );

    return this.getLicense(licenseKey);
  }

  getLicense(licenseKey) {
    const row = this.db.prepare(`
      SELECT *
      FROM licenses
      WHERE license_key = ?
      LIMIT 1
    `).get(licenseKey);

    if (!row) {
      return null;
    }

    return mapLicense(row, this.countActiveLicenseInstances(licenseKey));
  }

  createOrReuseLicenseInstance({ id, licenseKey, installationId, instanceName }) {
    const existing = this.db.prepare(`
      SELECT *
      FROM license_instances
      WHERE license_key = ?
        AND installation_id = ?
        AND status = 'active'
      LIMIT 1
    `).get(licenseKey, installationId);

    if (existing) {
      return {
        license: this.getLicense(licenseKey),
        instance: mapLicenseInstance(existing),
        reused: true
      };
    }

    const now = isoNow();
    this.db.prepare(`
      INSERT INTO license_instances (
        id,
        license_key,
        installation_id,
        instance_name,
        status,
        created_at,
        updated_at,
        last_validated_at
      ) VALUES (?, ?, ?, ?, 'active', ?, ?, ?)
    `).run(
      id,
      licenseKey,
      installationId,
      instanceName,
      now,
      now,
      now
    );

    return {
      license: this.getLicense(licenseKey),
      instance: this.getLicenseInstance({ licenseKey, instanceId: id }),
      reused: false
    };
  }

  getActiveLicenseInstanceForInstallation({ licenseKey, installationId }) {
    const row = this.db.prepare(`
      SELECT *
      FROM license_instances
      WHERE license_key = ?
        AND installation_id = ?
        AND status = 'active'
      LIMIT 1
    `).get(licenseKey, installationId);

    return mapLicenseInstance(row);
  }

  countActiveLicenseInstances(licenseKey) {
    const row = this.db.prepare(`
      SELECT COUNT(*) AS count
      FROM license_instances
      WHERE license_key = ?
        AND status = 'active'
    `).get(licenseKey);

    return Number(row?.count ?? 0);
  }

  getLicenseInstance({ licenseKey, instanceId }) {
    const row = this.db.prepare(`
      SELECT *
      FROM license_instances
      WHERE license_key = ?
        AND id = ?
      LIMIT 1
    `).get(licenseKey, instanceId);

    return mapLicenseInstance(row);
  }

  touchLicenseInstance(instanceId) {
    this.db.prepare(`
      UPDATE license_instances
      SET last_validated_at = ?,
          updated_at = ?
      WHERE id = ?
        AND status = 'active'
    `).run(
      isoNow(),
      isoNow(),
      instanceId
    );
  }

  deactivateLicenseInstance({ licenseKey, instanceId }) {
    this.db.prepare(`
      UPDATE license_instances
      SET status = 'deactivated',
          deactivated_at = ?,
          updated_at = ?
      WHERE license_key = ?
        AND id = ?
        AND status = 'active'
    `).run(
      isoNow(),
      isoNow(),
      licenseKey,
      instanceId
    );

    return this.getLicenseInstance({ licenseKey, instanceId });
  }

  insertWebhookEvent({ eventName, resourceType, resourceId, payloadJson }) {
    const result = this.db.prepare(`
      INSERT INTO webhook_events (
        event_name,
        resource_type,
        resource_id,
        status,
        payload_json,
        received_at
      ) VALUES (?, ?, ?, 'received', ?, ?)
    `).run(
      eventName,
      resourceType ?? null,
      resourceId ?? null,
      payloadJson,
      isoNow()
    );

    return Number(result.lastInsertRowid);
  }

  finalizeWebhookEvent({ id, status, errorMessage }) {
    this.db.prepare(`
      UPDATE webhook_events
      SET status = ?,
          error_message = ?,
          processed_at = ?
      WHERE id = ?
    `).run(
      status,
      errorMessage ?? null,
      isoNow(),
      id
    );
  }
}
