import crypto from 'node:crypto';
import fs from 'node:fs';
import express from 'express';

import { loadConfig } from './config.js';
import { ChargeCatDatabase } from './database.js';
import {
  renderCheckoutFailurePage,
  renderCheckoutPendingPage,
  renderCheckoutReturnPage,
  renderCheckoutThanksPage,
  renderTossCheckoutPage
} from './html.js';
import { LemonClient } from './lemon-client.js';
import { TossAPIError, TossClient } from './toss-client.js';
import {
  activateLicenseSchema,
  assetDownloadRequestSchema,
  claimCheckoutSessionSchema,
  createCheckoutSessionSchema,
  deactivateLicenseSchema,
  publicCheckoutSchema,
  sessionLookupSchema,
  validateLicenseSchema
} from './validators.js';

const config = loadConfig();
const database = new ChargeCatDatabase(config.databasePath);
const lemonClient = new LemonClient(config);
const tossClient = new TossClient(config);

const app = express();
app.disable('x-powered-by');

function now() {
  return new Date();
}

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function createSessionId() {
  return crypto.randomUUID();
}

function createOrderId(sessionId) {
  return `toss_${sessionId.replaceAll('-', '')}`.slice(0, 64);
}

function createChargeCatLicenseKey() {
  return `ccp_${crypto.randomBytes(16).toString('hex')}`;
}

function baseUrlString() {
  return config.publicBaseUrl?.toString().replace(/\/$/, '') ?? '';
}

function publicUrl(pathname) {
  return `${baseUrlString()}${pathname.startsWith('/') ? pathname : `/${pathname}`}`;
}

function appOpenUrl(sessionId) {
  return `${config.appCustomScheme}://checkout-complete?session_id=${encodeURIComponent(sessionId)}`;
}

function isSafeAssetPath(pathname) {
  if (!pathname) {
    return false;
  }

  return pathname.split('/').every((segment) => {
    const trimmed = segment.trim();
    return trimmed && trimmed !== '.' && trimmed !== '..';
  });
}

function loadAssetCatalog() {
  let rawCatalog;
  try {
    rawCatalog = fs.readFileSync(config.assetCatalogPath, 'utf8');
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && error.code === 'ENOENT') {
      return [];
    }
    throw error;
  }

  const parsed = JSON.parse(rawCatalog);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed.assets) === false) {
    throw new Error('Asset catalog must be an object with an assets array.');
  }

  return parsed.assets.flatMap((asset) => {
    if (!asset || typeof asset !== 'object') {
      return [];
    }

    const id = typeof asset.id === 'string' ? asset.id.trim() : '';
    const title = typeof asset.title === 'string' ? asset.title.trim() : '';
    const mediaType = asset.mediaType === 'gif' ? 'gif' : asset.mediaType === 'video' ? 'video' : '';
    if (!id || !title || !mediaType) {
      return [];
    }

    const filename = typeof asset.filename === 'string' ? asset.filename.trim() : '';
    const rawSourceDownloadURL = typeof asset.downloadURL === 'string' ? asset.downloadURL.trim() : '';
    let sourceDownloadURL = '';
    if (rawSourceDownloadURL) {
      try {
        sourceDownloadURL = new URL(rawSourceDownloadURL).toString();
      } catch {
        sourceDownloadURL = '';
      }
    }

    if (!filename && !sourceDownloadURL) {
      return [];
    }

    const previewHeight = Number(asset.previewHeight);
    const overlayHeight = Number(asset.overlayHeight);
    const recommendedEvent = asset.recommendedEvent === 'chargeStarted' || asset.recommendedEvent === 'fullyCharged'
      ? asset.recommendedEvent
      : null;

    return [{
      id,
      title,
      mediaType,
      downloadURL: publicUrl(`/api/assets/download/${encodeURIComponent(id)}`),
      sourceDownloadURL,
      filename,
      systemImage: typeof asset.systemImage === 'string' && asset.systemImage.trim()
        ? asset.systemImage.trim()
        : null,
      soundProfile: asset.soundProfile === 'doorCat' ? 'doorCat' : 'silent',
      previewHeight: Number.isFinite(previewHeight) && previewHeight > 0 ? previewHeight : null,
      overlayHeight: Number.isFinite(overlayHeight) && overlayHeight > 0 ? overlayHeight : null,
      recommendedEvent
    }];
  });
}

function serializeAssetForClient(asset) {
  return {
    id: asset.id,
    title: asset.title,
    mediaType: asset.mediaType,
    downloadURL: asset.downloadURL,
    systemImage: asset.systemImage,
    soundProfile: asset.soundProfile,
    previewHeight: asset.previewHeight,
    overlayHeight: asset.overlayHeight,
    recommendedEvent: asset.recommendedEvent
  };
}

function findAssetById(assetId) {
  return loadAssetCatalog().find((asset) => asset.id === assetId) ?? null;
}

async function authorizeAssetDownload({ licenseKey, instanceId }) {
  if (licenseKey.startsWith('ccp_')) {
    const license = database.getLicense(licenseKey);
    if (!license || license.provider !== 'chargeCat') {
      return { ok: false, status: 403, error: 'This Pro license could not be found.' };
    }

    if (license.status !== 'active') {
      return { ok: false, status: 403, error: 'This Pro license is no longer active.' };
    }

    const instance = database.getLicenseInstance({ licenseKey, instanceId });
    if (!instance || instance.status !== 'active') {
      return { ok: false, status: 403, error: 'This Mac is not currently activated for Pro downloads.' };
    }

    database.touchLicenseInstance(instanceId);
    return { ok: true };
  }

  if (config.isLemonConfigured === false) {
    return { ok: false, status: 503, error: 'Lemon validation is not configured on this backend.' };
  }

  try {
    const response = await lemonClient.validateLicense({ licenseKey, instanceId });
    if (!response?.valid) {
      return {
        ok: false,
        status: 403,
        error: response?.error || 'This Pro license could not be verified for downloads.'
      };
    }

    const licenseStatus = response?.license_key?.status;
    if (licenseStatus === 'disabled' || licenseStatus === 'expired') {
      return { ok: false, status: 403, error: 'This Pro license is no longer active.' };
    }

    const meta = response?.meta ?? {};
    if (Number(meta.store_id) !== config.lemonStoreId ||
        Number(meta.product_id) !== config.lemonProductId ||
        Number(meta.variant_id) !== config.lemonVariantId) {
      return { ok: false, status: 403, error: 'This license belongs to a different product.' };
    }

    if (response?.instance?.id !== instanceId) {
      return { ok: false, status: 403, error: 'This Mac activation could not be verified.' };
    }

    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      status: 502,
      error: error instanceof Error ? error.message : 'Could not verify this Pro license right now.'
    };
  }
}

function chooseCheckoutProvider(requestedProvider) {
  if (requestedProvider === 'toss') {
    if (config.isTossConfigured === false) {
      throw new Error('Toss Payments checkout is not configured yet.');
    }
    return 'toss';
  }

  if (requestedProvider === 'lemon') {
    if (config.isLemonConfigured === false) {
      throw new Error('Lemon Squeezy checkout is not configured yet.');
    }
    return 'lemon';
  }

  if (config.defaultCheckoutProvider === 'toss' && config.isTossConfigured) {
    return 'toss';
  }

  if (config.defaultCheckoutProvider === 'lemon' && config.isLemonConfigured) {
    return 'lemon';
  }

  if (config.isTossConfigured) {
    return 'toss';
  }

  if (config.isLemonConfigured) {
    return 'lemon';
  }

  throw new Error('Backend checkout is not configured yet.');
}

function verifyWebhookSignature(rawBody, signature) {
  if (!config.lemonWebhookSecret || !signature || !rawBody) {
    return false;
  }

  const digest = Buffer.from(
    crypto.createHmac('sha256', config.lemonWebhookSecret).update(rawBody).digest('hex'),
    'hex'
  );
  const provided = Buffer.from(signature, 'hex');

  if (digest.length === 0 || provided.length === 0 || digest.length !== provided.length) {
    return false;
  }

  return crypto.timingSafeEqual(digest, provided);
}

function installationMismatchResponse(response) {
  response.status(403).json({
    error: 'This checkout session belongs to a different Charge Cat installation.'
  });
}

function normalizeSessionForClient(session) {
  return {
    sessionId: session.id,
    provider: session.provider,
    status: session.status,
    customerEmail: session.customerEmail,
    checkoutUrl: session.checkoutUrl,
    expiresAt: session.expiresAt,
    completedAt: session.completedAt,
    claimedAt: session.claimedAt,
    lastError: session.lastError
  };
}

function serializeLicense(license) {
  if (!license) {
    return null;
  }

  return {
    key: license.key,
    status: license.status,
    activationLimit: license.activationLimit,
    activationUsage: license.activationUsage
  };
}

function serializeLicenseInstance(instance) {
  if (!instance) {
    return null;
  }

  return {
    id: instance.id,
    name: instance.name
  };
}

function completeChargeCatSession({ session, payment }) {
  const existingLicenseKey = session.licenseKey;
  const licenseKey = existingLicenseKey || createChargeCatLicenseKey();

  if (!existingLicenseKey) {
    database.createLicense({
      licenseKey,
      provider: 'chargeCat',
      customerEmail: payment.customerEmail ?? session.customerEmail,
      activationLimit: 3,
      orderId: session.orderId
    });
  }

  return database.completeCheckoutSession({
    id: session.id,
    provider: 'toss',
    customerEmail: payment.customerEmail ?? session.customerEmail,
    licenseKey,
    orderId: payment.orderId ?? session.orderId,
    paymentKey: payment.paymentKey ?? session.paymentKey,
    paymentMethod: payment.method ?? session.paymentMethod,
    paymentStatus: payment.status ?? session.paymentStatus
  });
}

function renderCompletionForSession(session) {
  if (session.source === 'app') {
    return renderCheckoutReturnPage({
      appOpenUrl: appOpenUrl(session.id),
      myOrdersUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues',
      secondaryLabel: 'Need Help?'
    });
  }

  if (session.provider === 'toss') {
    return renderCheckoutThanksPage({
      title: 'Charge Cat Pro is ready',
      heading: 'Your Charge Cat Pro purchase is complete.',
      description: 'Save this license key for later. If Charge Cat is already installed, you can paste it into the app. If not, download the app first and activate there.',
      appDownloadUrl: config.appDownloadUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/releases',
      myOrdersUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues',
      secondaryLabel: 'Support',
      licenseKey: session.licenseKey,
      customerEmail: session.customerEmail
    });
  }

  return renderCheckoutThanksPage({
    appDownloadUrl: config.appDownloadUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/releases',
    myOrdersUrl: config.myOrdersUrl?.toString() ?? 'https://app.lemonsqueezy.com/my-orders'
  });
}

async function createTossSession({ sessionId, customerEmail, installationId, source, appVersion }) {
  const expiresAt = addMinutes(now(), 30).toISOString();
  const orderId = createOrderId(sessionId);
  const checkoutUrl = publicUrl(`/checkout/toss/${sessionId}`);

  database.createCheckoutSession({
    id: sessionId,
    provider: 'toss',
    installationId,
    customerEmail,
    source,
    appVersion,
    expiresAt
  });

  return database.attachCheckout({
    id: sessionId,
    provider: 'toss',
    checkoutId: orderId,
    checkoutUrl,
    orderId,
    orderAmount: config.proPriceKrw,
    orderCurrency: 'KRW'
  });
}

async function createLemonSession({ sessionId, customerEmail, installationId, source, appVersion }) {
  const expiresAt = addMinutes(now(), 30).toISOString();

  database.createCheckoutSession({
    id: sessionId,
    provider: 'lemon',
    installationId,
    customerEmail,
    source,
    appVersion,
    expiresAt
  });

  const checkout = source === 'app'
    ? await lemonClient.createAppCheckout({
        sessionId,
        installationId,
        customerEmail,
        source
      })
    : await lemonClient.createWebsiteCheckout({
        customerEmail
      });

  return database.attachCheckout({
    id: sessionId,
    provider: 'lemon',
    checkoutId: checkout.id,
    checkoutUrl: checkout.url
  });
}

async function confirmTossPayment({ session, paymentKey, orderId, amount }) {
  if (!paymentKey || !orderId || Number.isFinite(amount) === false) {
    throw new Error('Toss did not return the payment details needed to confirm the order.');
  }

  if (session.orderId && session.orderId !== orderId) {
    throw new Error('This payment does not match the stored checkout session.');
  }

  if (session.orderAmount && Number(session.orderAmount) !== amount) {
    throw new Error('The payment amount did not match the expected Charge Cat Pro price.');
  }

  try {
    return await tossClient.confirmPayment({
      paymentKey,
      orderId,
      amount
    });
  } catch (error) {
    if (error instanceof TossAPIError && error.code === 'ALREADY_PROCESSED_PAYMENT') {
      return tossClient.getPaymentByOrderId(orderId);
    }
    throw error;
  }
}

app.get('/healthz', (_request, response) => {
  let assetCount = 0;
  try {
    assetCount = loadAssetCatalog().length;
  } catch {
    assetCount = 0;
  }

  response.json({
    ok: true,
    lemonConfigured: config.isLemonConfigured,
    tossConfigured: config.isTossConfigured,
    defaultCheckoutProvider: config.defaultCheckoutProvider,
    assetCount
  });
});

app.get('/api/assets/catalog', (_request, response) => {
  try {
    response.json({
      assets: loadAssetCatalog().map(serializeAssetForClient)
    });
  } catch (error) {
    response.status(500).json({
      error: error instanceof Error ? error.message : 'Could not load the asset catalog.'
    });
  }
});

app.get('/api/assets/download/:assetId', async (request, response) => {
  const parsed = assetDownloadRequestSchema.safeParse({
    assetId: request.params.assetId,
    licenseKey: request.get('X-ChargeCat-License-Key'),
    instanceId: request.get('X-ChargeCat-Instance-ID')
  });

  if (!parsed.success) {
    response.status(400).json({
      error: 'A valid Pro license is required to download this asset.'
    });
    return;
  }

  const asset = findAssetById(parsed.data.assetId);
  if (!asset) {
    response.status(404).json({
      error: 'Asset not found.'
    });
    return;
  }

  const authorization = await authorizeAssetDownload({
    licenseKey: parsed.data.licenseKey,
    instanceId: parsed.data.instanceId
  });
  if (!authorization.ok) {
    response.status(authorization.status).json({
      error: authorization.error
    });
    return;
  }

  if (asset.filename) {
    if (isSafeAssetPath(asset.filename) === false) {
      response.status(400).json({
        error: 'Asset filename is not valid.'
      });
      return;
    }

    response.sendFile(asset.filename, {
      root: config.assetFilesPath,
      dotfiles: 'deny',
      cacheControl: true,
      maxAge: '1h'
    }, (error) => {
      if (error && response.headersSent === false) {
        response.status(error.statusCode || 404).json({
          error: 'The requested asset file could not be found.'
        });
      }
    });
    return;
  }

  try {
    const upstream = await fetch(asset.sourceDownloadURL);
    if (!upstream.ok) {
      response.status(502).json({
        error: 'The upstream asset file could not be fetched.'
      });
      return;
    }

    const contentType = upstream.headers.get('content-type');
    if (contentType) {
      response.setHeader('Content-Type', contentType);
    }
    response.setHeader('Cache-Control', 'private, max-age=3600');
    const buffer = Buffer.from(await upstream.arrayBuffer());
    response.status(200).send(buffer);
  } catch (error) {
    response.status(502).json({
      error: error instanceof Error ? error.message : 'The upstream asset file could not be fetched.'
    });
  }
});

app.post('/api/checkout-sessions', express.json(), async (request, response) => {
  if (config.hasCheckoutProvider === false) {
    response.status(503).json({
      error: 'Backend checkout is not configured yet.'
    });
    return;
  }

  const parsed = createCheckoutSessionSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'Invalid checkout session payload.',
      details: parsed.error.flatten()
    });
    return;
  }

  const payload = parsed.data;
  const sessionId = createSessionId();

  try {
    const provider = chooseCheckoutProvider(payload.provider);
    const session = provider === 'toss'
      ? await createTossSession({
          sessionId,
          installationId: payload.installationId,
          customerEmail: payload.customerEmail,
          source: payload.source,
          appVersion: payload.appVersion
        })
      : await createLemonSession({
          sessionId,
          installationId: payload.installationId,
          customerEmail: payload.customerEmail,
          source: payload.source,
          appVersion: payload.appVersion
        });

    response.status(201).json(normalizeSessionForClient(session));
  } catch (error) {
    database.markCheckoutFailed({
      id: sessionId,
      errorMessage: error instanceof Error ? error.message : 'Unknown checkout error.'
    });

    response.status(502).json({
      error: error instanceof Error ? error.message : 'Could not create a checkout session.'
    });
  }
});

app.get('/api/checkout-sessions/:sessionId', (request, response) => {
  const parsed = sessionLookupSchema.safeParse({
    sessionId: request.params.sessionId,
    installationId: request.query.installationId
  });

  if (!parsed.success) {
    response.status(400).json({
      error: 'Invalid checkout session lookup.'
    });
    return;
  }

  let session = database.getCheckoutSession(parsed.data.sessionId);
  if (!session) {
    response.status(404).json({
      error: 'Checkout session not found.'
    });
    return;
  }

  if (session.installationId !== parsed.data.installationId) {
    installationMismatchResponse(response);
    return;
  }

  if (session.status === 'pending' && new Date(session.expiresAt).getTime() < Date.now()) {
    session = database.markCheckoutExpired(session.id);
  }

  const payload = normalizeSessionForClient(session);
  if (session.status === 'ready' && session.licenseKey) {
    response.json({
      ...payload,
      licenseKey: session.licenseKey
    });
    return;
  }

  response.json(payload);
});

app.post('/api/checkout-sessions/:sessionId/claim', express.json(), (request, response) => {
  const parsed = claimCheckoutSessionSchema.safeParse(request.body);
  if (!parsed.success) {
    response.status(400).json({
      error: 'Invalid checkout session claim payload.'
    });
    return;
  }

  const session = database.getCheckoutSession(request.params.sessionId);
  if (!session) {
    response.status(404).json({
      error: 'Checkout session not found.'
    });
    return;
  }

  if (session.installationId !== parsed.data.installationId) {
    installationMismatchResponse(response);
    return;
  }

  const claimed = database.claimCheckoutSession({
    id: session.id,
    installationId: parsed.data.installationId
  });

  response.json(normalizeSessionForClient(claimed));
});

app.post('/api/licenses/activate', express.json(), (request, response) => {
  const parsed = activateLicenseSchema.safeParse(request.body);
  if (!parsed.success) {
    response.json({
      activated: false,
      error: 'Invalid license activation payload.',
      license: null,
      instance: null,
      customerEmail: null
    });
    return;
  }

  const payload = parsed.data;
  const license = database.getLicense(payload.licenseKey);
  if (!license || license.provider !== 'chargeCat') {
    response.json({
      activated: false,
      error: 'License key could not be found.',
      license: null,
      instance: null,
      customerEmail: payload.customerEmail
    });
    return;
  }

  if (license.status !== 'active') {
    response.json({
      activated: false,
      error: 'This Charge Cat Pro license is no longer active.',
      license: serializeLicense(license),
      instance: null,
      customerEmail: license.customerEmail ?? payload.customerEmail
    });
    return;
  }

  const existingInstance = database.getActiveLicenseInstanceForInstallation({
    licenseKey: payload.licenseKey,
    installationId: payload.installationId
  });

  if (!existingInstance && license.activationUsage >= license.activationLimit) {
    response.json({
      activated: false,
      error: 'This license has reached its activation limit.',
      license: serializeLicense(license),
      instance: null,
      customerEmail: license.customerEmail ?? payload.customerEmail
    });
    return;
  }

  const activation = database.createOrReuseLicenseInstance({
    id: existingInstance?.id ?? createSessionId(),
    licenseKey: payload.licenseKey,
    installationId: payload.installationId,
    instanceName: payload.instanceName
  });

  response.json({
    activated: true,
    error: null,
    license: serializeLicense(activation.license),
    instance: serializeLicenseInstance(activation.instance),
    customerEmail: activation.license?.customerEmail ?? payload.customerEmail
  });
});

app.post('/api/licenses/validate', express.json(), (request, response) => {
  const parsed = validateLicenseSchema.safeParse(request.body);
  if (!parsed.success) {
    response.json({
      valid: false,
      error: 'Invalid license validation payload.',
      license: null,
      instance: null,
      customerEmail: null
    });
    return;
  }

  const payload = parsed.data;
  const license = database.getLicense(payload.licenseKey);
  if (!license || license.provider !== 'chargeCat') {
    response.json({
      valid: false,
      error: 'License key could not be found.',
      license: null,
      instance: null,
      customerEmail: null
    });
    return;
  }

  if (license.status !== 'active') {
    response.json({
      valid: false,
      error: 'This Charge Cat Pro license is no longer active.',
      license: serializeLicense(license),
      instance: null,
      customerEmail: license.customerEmail
    });
    return;
  }

  if (!payload.instanceId) {
    response.json({
      valid: false,
      error: 'A saved activation for this Mac could not be found.',
      license: serializeLicense(license),
      instance: null,
      customerEmail: license.customerEmail
    });
    return;
  }

  const instance = database.getLicenseInstance({
    licenseKey: payload.licenseKey,
    instanceId: payload.instanceId
  });

  if (!instance || instance.status !== 'active') {
    response.json({
      valid: false,
      error: 'The saved activation on this Mac is no longer valid.',
      license: serializeLicense(license),
      instance: serializeLicenseInstance(instance),
      customerEmail: license.customerEmail
    });
    return;
  }

  database.touchLicenseInstance(instance.id);
  const freshLicense = database.getLicense(payload.licenseKey);
  const freshInstance = database.getLicenseInstance({
    licenseKey: payload.licenseKey,
    instanceId: payload.instanceId
  });

  response.json({
    valid: true,
    error: null,
    license: serializeLicense(freshLicense),
    instance: serializeLicenseInstance(freshInstance),
    customerEmail: freshLicense?.customerEmail
  });
});

app.post('/api/licenses/deactivate', express.json(), (request, response) => {
  const parsed = deactivateLicenseSchema.safeParse(request.body);
  if (!parsed.success) {
    response.json({
      deactivated: false,
      error: 'Invalid license deactivation payload.'
    });
    return;
  }

  const payload = parsed.data;
  const license = database.getLicense(payload.licenseKey);
  if (!license || license.provider !== 'chargeCat') {
    response.json({
      deactivated: false,
      error: 'License key could not be found.'
    });
    return;
  }

  const instance = database.getLicenseInstance({
    licenseKey: payload.licenseKey,
    instanceId: payload.instanceId
  });

  if (!instance || instance.status !== 'active') {
    response.json({
      deactivated: false,
      error: 'This Mac is not currently activated.'
    });
    return;
  }

  database.deactivateLicenseInstance({
    licenseKey: payload.licenseKey,
    instanceId: payload.instanceId
  });

  response.json({
    deactivated: true,
    error: null
  });
});

app.post('/webhooks/lemon', express.raw({ type: 'application/json' }), (request, response) => {
  const rawBody = Buffer.isBuffer(request.body) ? request.body.toString('utf8') : '';
  const signature = request.get('X-Signature') || '';
  if (verifyWebhookSignature(rawBody, signature) === false) {
    response.status(401).json({
      error: 'Invalid webhook signature.'
    });
    return;
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    response.status(400).json({
      error: 'Webhook body was not valid JSON.'
    });
    return;
  }

  const eventName = request.get('X-Event-Name') || payload?.meta?.event_name || 'unknown';
  const webhookLogId = database.insertWebhookEvent({
    eventName,
    resourceType: payload?.data?.type,
    resourceId: payload?.data?.id,
    payloadJson: rawBody
  });

  try {
    const customData = payload?.meta?.custom_data ?? {};
    const sessionId = typeof customData.session_id === 'string' ? customData.session_id : null;

    if (eventName === 'order_created' && sessionId) {
      const attributes = payload?.data?.attributes ?? {};
      database.recordOrderCreated({
        id: sessionId,
        orderId: attributes.id ? String(attributes.id) : String(payload?.data?.id ?? ''),
        orderIdentifier: attributes.identifier ?? null,
        customerEmail: attributes.user_email ?? null
      });
    }

    if (eventName === 'license_key_created' && sessionId) {
      const attributes = payload?.data?.attributes ?? {};
      const session = database.getCheckoutSession(sessionId);
      if (!session) {
        throw new Error(`Unknown checkout session: ${sessionId}`);
      }

      const webhookInstallationId = typeof customData.installation_id === 'string' ? customData.installation_id : '';
      if (webhookInstallationId && session.installationId !== webhookInstallationId) {
        throw new Error('Webhook installation did not match the stored checkout session.');
      }

      if (Number(attributes.store_id) !== config.lemonStoreId || Number(attributes.product_id) !== config.lemonProductId) {
        throw new Error('Webhook product did not match Charge Cat Pro.');
      }

      if (!attributes.key) {
        throw new Error('License webhook did not include a license key.');
      }

      database.completeCheckoutSession({
        id: sessionId,
        provider: 'lemon',
        customerEmail: attributes.user_email ?? session.customerEmail,
        licenseKey: attributes.key,
        orderId: attributes.order_id ? String(attributes.order_id) : session.orderId,
        storeId: attributes.store_id ? Number(attributes.store_id) : null,
        productId: attributes.product_id ? Number(attributes.product_id) : null,
        variantId: attributes.variant_id ? Number(attributes.variant_id) : null
      });
    }

    database.finalizeWebhookEvent({
      id: webhookLogId,
      status: 'processed',
      errorMessage: null
    });

    response.status(200).json({
      ok: true
    });
  } catch (error) {
    database.finalizeWebhookEvent({
      id: webhookLogId,
      status: 'error',
      errorMessage: error instanceof Error ? error.message : 'Unknown webhook error.'
    });

    response.status(500).json({
      error: error instanceof Error ? error.message : 'Webhook processing failed.'
    });
  }
});

app.get('/buy/pro', async (request, response) => {
  const parsed = publicCheckoutSchema.safeParse({
    customerEmail: request.query.email,
    provider: request.query.provider
  });

  if (!parsed.success) {
    response.status(400).send('Invalid checkout request.');
    return;
  }

  try {
    const provider = chooseCheckoutProvider(parsed.data.provider);
    if (provider === 'lemon') {
      const checkout = await lemonClient.createWebsiteCheckout({
        customerEmail: parsed.data.customerEmail
      });
      response.redirect(checkout.url);
      return;
    }

    const session = await createTossSession({
      sessionId: createSessionId(),
      installationId: createSessionId(),
      customerEmail: parsed.data.customerEmail,
      source: 'web',
      appVersion: null
    });
    response.redirect(session.checkoutUrl);
  } catch (error) {
    response.status(502).send(error instanceof Error ? error.message : 'Could not create checkout.');
  }
});

app.get('/checkout/toss/:sessionId', (request, response) => {
  if (config.isTossConfigured === false) {
    response.status(503).send('Toss Payments checkout is not configured yet.');
    return;
  }

  let session = database.getCheckoutSession(request.params.sessionId);
  if (!session || session.provider !== 'toss') {
    response.status(404).send('Checkout session not found.');
    return;
  }

  if (session.status === 'pending' && new Date(session.expiresAt).getTime() < Date.now()) {
    session = database.markCheckoutExpired(session.id);
  }

  if (session.status === 'ready' || session.status === 'claimed') {
    response.type('html').send(renderCompletionForSession(session));
    return;
  }

  if (session.status === 'expired') {
    response.type('html').send(renderCheckoutFailurePage({
      title: 'Checkout expired',
      heading: 'This checkout session has expired.',
      description: 'Please start a new Charge Cat Pro checkout from the app or website.',
      retryUrl: publicUrl('/buy/pro?provider=toss'),
      supportUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues',
      openAppUrl: session.source === 'app' ? appOpenUrl(session.id) : null
    }));
    return;
  }

  response.type('html').send(renderTossCheckoutPage({
    clientKey: config.tossWidgetClientKey,
    variantKey: config.tossWidgetVariantKey,
    customerKey: session.installationId || session.id,
    orderId: session.orderId,
    orderName: config.productName,
    amount: session.orderAmount ?? config.proPriceKrw,
    customerEmail: session.customerEmail,
    successUrl: `${publicUrl('/checkout/toss/success')}?session_id=${encodeURIComponent(session.id)}`,
    failUrl: `${publicUrl('/checkout/toss/fail')}?session_id=${encodeURIComponent(session.id)}`,
    supportUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues'
  }));
});

app.get('/checkout/toss/success', async (request, response) => {
  const sessionId = typeof request.query.session_id === 'string' ? request.query.session_id : '';
  const paymentKey = typeof request.query.paymentKey === 'string' ? request.query.paymentKey : '';
  const orderId = typeof request.query.orderId === 'string' ? request.query.orderId : '';
  const amount = Number(request.query.amount);

  const session = database.getCheckoutSession(sessionId);
  if (!session || session.provider !== 'toss') {
    response.status(404).send('Checkout session not found.');
    return;
  }

  if (session.status === 'ready' || session.status === 'claimed') {
    response.type('html').send(renderCompletionForSession(session));
    return;
  }

  try {
    const payment = await confirmTossPayment({
      session,
      paymentKey,
      orderId,
      amount
    });

    database.updateCheckoutPaymentState({
      id: session.id,
      paymentKey: payment.paymentKey ?? paymentKey,
      paymentMethod: payment.method ?? null,
      paymentStatus: payment.status ?? null,
      errorMessage: null
    });

    if (String(payment.orderId) !== String(session.orderId)) {
      throw new Error('This payment confirmation did not match the stored order.');
    }

    const paymentAmount = Number(payment.totalAmount ?? payment.balanceAmount ?? payment.amount ?? amount);
    if (Number.isFinite(paymentAmount) && session.orderAmount && paymentAmount !== Number(session.orderAmount)) {
      throw new Error('The approved payment amount did not match the expected Charge Cat Pro price.');
    }

    if (payment.status !== 'DONE') {
      response.type('html').send(renderCheckoutPendingPage({
        title: 'Payment is still processing',
        heading: 'Your payment is still being finalized.',
        description: 'Some Toss payment methods complete instantly, while others can stay pending for a little longer. Refresh this page after the payment is confirmed.',
        refreshUrl: request.originalUrl,
        supportUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues',
        openAppUrl: session.source === 'app' ? appOpenUrl(session.id) : null
      }));
      return;
    }

    const completedSession = completeChargeCatSession({
      session,
      payment
    });

    response.type('html').send(renderCompletionForSession(completedSession));
  } catch (error) {
    database.markCheckoutFailed({
      id: session.id,
      errorMessage: error instanceof Error ? error.message : 'Could not confirm the Toss payment.'
    });

    response.type('html').send(renderCheckoutFailurePage({
      title: 'Payment confirmation failed',
      heading: 'We could not finish this Charge Cat Pro payment.',
      description: error instanceof Error ? error.message : 'Please try the payment again.',
      retryUrl: publicUrl(`/checkout/toss/${session.id}`),
      supportUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues',
      openAppUrl: session.source === 'app' ? appOpenUrl(session.id) : null,
      errorCode: error instanceof TossAPIError ? error.code : null,
      errorMessage: error instanceof Error ? error.message : null
    }));
  }
});

app.get('/checkout/toss/fail', (request, response) => {
  const sessionId = typeof request.query.session_id === 'string' ? request.query.session_id : '';
  const code = typeof request.query.code === 'string' ? request.query.code : '';
  const message = typeof request.query.message === 'string' ? request.query.message : 'The payment was not completed.';
  const session = database.getCheckoutSession(sessionId);

  if (session) {
    database.markCheckoutFailed({
      id: session.id,
      errorMessage: code ? `${code}: ${message}` : message
    });
  }

  response.type('html').send(renderCheckoutFailurePage({
    title: 'Payment cancelled',
    heading: code === 'PAY_PROCESS_CANCELED' ? 'Payment was cancelled.' : 'Payment did not complete.',
    description: message,
    retryUrl: session ? publicUrl(`/checkout/toss/${session.id}`) : publicUrl('/buy/pro?provider=toss'),
    supportUrl: config.supportUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/issues',
    openAppUrl: session?.source === 'app' ? appOpenUrl(session.id) : null,
    errorCode: code,
    errorMessage: message
  }));
});

app.get('/checkout/return', (request, response) => {
  const sessionId = typeof request.query.session_id === 'string' ? request.query.session_id : '';

  response.type('html').send(renderCheckoutReturnPage({
    appOpenUrl: appOpenUrl(sessionId),
    myOrdersUrl: config.myOrdersUrl?.toString() ?? 'https://app.lemonsqueezy.com/my-orders'
  }));
});

app.get('/checkout/thanks', (_request, response) => {
  response.type('html').send(renderCheckoutThanksPage({
    appDownloadUrl: config.appDownloadUrl?.toString() ?? 'https://github.com/coldmans/chargeCat/releases',
    myOrdersUrl: config.myOrdersUrl?.toString() ?? 'https://app.lemonsqueezy.com/my-orders'
  }));
});

app.listen(config.port, () => {
  console.log(`Charge Cat backend listening on http://localhost:${config.port}`);
});
