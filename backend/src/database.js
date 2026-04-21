import mysql from 'mysql2/promise';

function isoNow() {
  return new Date().toISOString();
}

function normalizePoolConfig({ host, port, user, password, database, connectionLimit } = {}) {
  return {
    host,
    port: port == null ? 3306 : Number(port),
    user,
    password,
    database,
    connectionLimit: connectionLimit == null ? 10 : Number(connectionLimit)
  };
}

let sharedPool = null;
let sharedPoolKey = null;

function getPool(config) {
  const poolConfig = normalizePoolConfig(config);
  const poolKey = JSON.stringify(poolConfig);

  if (sharedPool) {
    if (sharedPoolKey !== poolKey) {
      throw new Error('ChargeCatDatabase 풀이 다른 MySQL 설정으로 이미 초기화되었습니다.');
    }

    return sharedPool;
  }

  sharedPool = mysql.createPool({
    ...poolConfig,
    waitForConnections: true,
    queueLimit: 0,
    charset: 'utf8mb4',
    timezone: 'Z',
    dateStrings: true,
    enableKeepAlive: true
  });
  sharedPoolKey = poolKey;
  return sharedPool;
}

async function fetchOne(executor, sql, params = []) {
  const [rows] = await executor.execute(sql, params);
  return Array.isArray(rows) ? (rows[0] ?? null) : null;
}

async function fetchCheckoutSessionRow(executor, id) {
  return fetchOne(
    executor,
    `
      SELECT *
      FROM checkout_sessions
      WHERE id = ?
      LIMIT 1
    `,
    [id]
  );
}

async function fetchCheckoutSessionByOrderIdRow(executor, orderId) {
  return fetchOne(
    executor,
    `
      SELECT *
      FROM checkout_sessions
      WHERE order_id = ?
      LIMIT 1
    `,
    [orderId]
  );
}

async function fetchLicenseRow(executor, licenseKey) {
  return fetchOne(
    executor,
    `
      SELECT *
      FROM licenses
      WHERE license_key = ?
      LIMIT 1
    `,
    [licenseKey]
  );
}

async function fetchActiveLicenseCount(executor, licenseKey) {
  const row = await fetchOne(
    executor,
    `
      SELECT COUNT(*) AS count
      FROM license_instances
      WHERE license_key = ?
        AND status = 'active'
    `,
    [licenseKey]
  );

  return Number(row?.count ?? 0);
}

async function fetchLicenseInstanceRow(executor, { licenseKey, instanceId }) {
  return fetchOne(
    executor,
    `
      SELECT *
      FROM license_instances
      WHERE license_key = ?
        AND id = ?
      LIMIT 1
    `,
    [licenseKey, instanceId]
  );
}

async function fetchActiveLicenseInstanceRow(executor, { licenseKey, installationId }) {
  return fetchOne(
    executor,
    `
      SELECT *
      FROM license_instances
      WHERE license_key = ?
        AND installation_id = ?
        AND status = 'active'
      LIMIT 1
    `,
    [licenseKey, installationId]
  );
}

async function acquireLock(connection, lockName) {
  const row = await fetchOne(connection, 'SELECT GET_LOCK(?, 5) AS acquired', [lockName]);
  return Number(row?.acquired ?? 0) === 1;
}

async function releaseLock(connection, lockName) {
  await connection.execute('SELECT RELEASE_LOCK(?)', [lockName]);
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
  constructor({ host, port, user, password, database, connectionLimit }) {
    this.pool = getPool({ host, port, user, password, database, connectionLimit });
  }

  async createCheckoutSession({
    id,
    provider,
    installationId,
    customerEmail,
    source,
    appVersion,
    expiresAt
  }) {
    const now = isoNow();
    await this.pool.execute(`
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
    `, [
      id,
      provider,
      installationId,
      customerEmail ?? null,
      source,
      appVersion ?? null,
      now,
      now,
      expiresAt
    ]);

    return this.getCheckoutSession(id);
  }

  async getCheckoutSession(id) {
    const row = await fetchCheckoutSessionRow(this.pool, id);
    return mapSession(row);
  }

  async getCheckoutSessionByOrderId(orderId) {
    const row = await fetchCheckoutSessionByOrderIdRow(this.pool, orderId);
    return mapSession(row);
  }

  async attachCheckout({
    id,
    provider,
    checkoutId,
    checkoutUrl,
    orderId,
    orderAmount,
    orderCurrency
  }) {
    await this.pool.execute(`
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
    `, [
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
    ]);

    return this.getCheckoutSession(id);
  }

  async recordOrderCreated({ id, orderId, orderIdentifier, customerEmail }) {
    await this.pool.execute(`
      UPDATE checkout_sessions
      SET order_id = COALESCE(?, order_id),
          order_identifier = COALESCE(?, order_identifier),
          customer_email = COALESCE(?, customer_email),
          updated_at = ?
      WHERE id = ?
    `, [
      orderId ?? null,
      orderIdentifier ?? null,
      customerEmail ?? null,
      isoNow(),
      id
    ]);

    return this.getCheckoutSession(id);
  }

  async completeCheckoutSession({
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

    await this.pool.execute(`
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
    `, [
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
    ]);

    return this.getCheckoutSession(id);
  }

  async updateCheckoutPaymentState({ id, paymentKey, paymentMethod, paymentStatus, errorMessage }) {
    await this.pool.execute(`
      UPDATE checkout_sessions
      SET payment_key = COALESCE(?, payment_key),
          payment_method = COALESCE(?, payment_method),
          payment_status = COALESCE(?, payment_status),
          last_error = ?,
          updated_at = ?
      WHERE id = ?
    `, [
      paymentKey ?? null,
      paymentMethod ?? null,
      paymentStatus ?? null,
      errorMessage ?? null,
      isoNow(),
      id
    ]);

    return this.getCheckoutSession(id);
  }

  async markCheckoutFailed({ id, errorMessage }) {
    await this.pool.execute(`
      UPDATE checkout_sessions
      SET status = 'failed',
          last_error = ?,
          updated_at = ?
      WHERE id = ?
    `, [
      errorMessage,
      isoNow(),
      id
    ]);

    return this.getCheckoutSession(id);
  }

  async markCheckoutExpired(id) {
    await this.pool.execute(`
      UPDATE checkout_sessions
      SET status = 'expired',
          updated_at = ?
      WHERE id = ?
        AND status = 'pending'
    `, [
      isoNow(),
      id
    ]);

    return this.getCheckoutSession(id);
  }

  async claimCheckoutSession({ id, installationId }) {
    const session = await this.getCheckoutSession(id);
    if (!session || session.installationId !== installationId) {
      return null;
    }

    if (session.claimedAt) {
      return session;
    }

    const now = isoNow();
    await this.pool.execute(`
      UPDATE checkout_sessions
      SET status = 'claimed',
          claimed_at = ?,
          updated_at = ?
      WHERE id = ?
    `, [
      now,
      now,
      id
    ]);

    return this.getCheckoutSession(id);
  }

  async createLicense({ licenseKey, provider, customerEmail, activationLimit, orderId }) {
    const now = isoNow();
    await this.pool.execute(`
      INSERT IGNORE INTO licenses (
        license_key,
        provider,
        customer_email,
        status,
        activation_limit,
        order_id,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, 'active', ?, ?, ?, ?)
    `, [
      licenseKey,
      provider,
      customerEmail ?? null,
      activationLimit,
      orderId ?? null,
      now,
      now
    ]);

    return this.getLicense(licenseKey);
  }

  async getLicense(licenseKey) {
    const row = await fetchLicenseRow(this.pool, licenseKey);
    if (!row) {
      return null;
    }

    return mapLicense(row, await fetchActiveLicenseCount(this.pool, licenseKey));
  }

  async createOrReuseLicenseInstance({ id, licenseKey, installationId, instanceName }) {
    const connection = await this.pool.getConnection();
    const lockName = `chargecat:license-instance:${licenseKey}:${installationId}`;

    try {
      const lockAcquired = await acquireLock(connection, lockName);
      if (!lockAcquired) {
        throw new Error('라이선스 인스턴스 잠금을 획득하지 못했습니다.');
      }

      await connection.beginTransaction();

      const existing = await fetchActiveLicenseInstanceRow(connection, { licenseKey, installationId });
      if (existing) {
        const [licenseRow, activationUsage] = await Promise.all([
          fetchLicenseRow(connection, licenseKey),
          fetchActiveLicenseCount(connection, licenseKey)
        ]);

        await connection.commit();

        return {
          license: mapLicense(licenseRow, activationUsage),
          instance: mapLicenseInstance(existing),
          reused: true
        };
      }

      const now = isoNow();
      await connection.execute(`
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
      `, [
        id,
        licenseKey,
        installationId,
        instanceName,
        now,
        now,
        now
      ]);

      const [licenseRow, instanceRow, activationUsage] = await Promise.all([
        fetchLicenseRow(connection, licenseKey),
        fetchLicenseInstanceRow(connection, { licenseKey, instanceId: id }),
        fetchActiveLicenseCount(connection, licenseKey)
      ]);

      await connection.commit();

      return {
        license: mapLicense(licenseRow, activationUsage),
        instance: mapLicenseInstance(instanceRow),
        reused: false
      };
    } catch (error) {
      try {
        await connection.rollback();
      } catch {
      }
      throw error;
    } finally {
      try {
        await releaseLock(connection, lockName);
      } catch {
      }
      connection.release();
    }
  }

  async getActiveLicenseInstanceForInstallation({ licenseKey, installationId }) {
    const row = await fetchActiveLicenseInstanceRow(this.pool, { licenseKey, installationId });
    return mapLicenseInstance(row);
  }

  async countActiveLicenseInstances(licenseKey) {
    return fetchActiveLicenseCount(this.pool, licenseKey);
  }

  async getLicenseInstance({ licenseKey, instanceId }) {
    const row = await fetchLicenseInstanceRow(this.pool, { licenseKey, instanceId });
    return mapLicenseInstance(row);
  }

  async touchLicenseInstance(instanceId) {
    const now = isoNow();
    await this.pool.execute(`
      UPDATE license_instances
      SET last_validated_at = ?,
          updated_at = ?
      WHERE id = ?
        AND status = 'active'
    `, [
      now,
      now,
      instanceId
    ]);
  }

  async deactivateLicenseInstance({ licenseKey, instanceId }) {
    const now = isoNow();
    await this.pool.execute(`
      UPDATE license_instances
      SET status = 'deactivated',
          deactivated_at = ?,
          updated_at = ?
      WHERE license_key = ?
        AND id = ?
        AND status = 'active'
    `, [
      now,
      now,
      licenseKey,
      instanceId
    ]);

    return this.getLicenseInstance({ licenseKey, instanceId });
  }

  async insertWebhookEvent({ eventName, resourceType, resourceId, payloadJson }) {
    const [result] = await this.pool.execute(`
      INSERT INTO webhook_events (
        event_name,
        resource_type,
        resource_id,
        status,
        payload_json,
        received_at
      ) VALUES (?, ?, ?, 'received', ?, ?)
    `, [
      eventName,
      resourceType ?? null,
      resourceId ?? null,
      payloadJson,
      isoNow()
    ]);

    return Number(result.insertId);
  }

  async finalizeWebhookEvent({ id, status, errorMessage }) {
    await this.pool.execute(`
      UPDATE webhook_events
      SET status = ?,
          error_message = ?,
          processed_at = ?
      WHERE id = ?
    `, [
      status,
      errorMessage ?? null,
      isoNow(),
      id
    ]);
  }
}
