import path from 'node:path';
import { fileURLToPath } from 'node:url';

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function envString(name, fallback = '') {
  return process.env[name]?.trim() || fallback;
}

function envNumber(name, fallback = 0) {
  const raw = process.env[name]?.trim();
  if (!raw) {
    return fallback;
  }

  const value = Number(raw);
  if (Number.isFinite(value) === false) {
    throw new Error(`${name} must be a number.`);
  }

  return value;
}

function envUrl(name, fallback = '') {
  const raw = envString(name, fallback);
  if (!raw) {
    return null;
  }

  try {
    return new URL(raw);
  } catch {
    throw new Error(`${name} must be a valid absolute URL.`);
  }
}

function resolvePath(input) {
  if (path.isAbsolute(input)) {
    return input;
  }

  return path.resolve(backendRoot, input);
}

export function loadConfig() {
  const publicBaseUrl = envUrl('PUBLIC_BASE_URL');
  const appCustomScheme = envString('APP_CUSTOM_SCHEME', 'chargecat').toLowerCase();
  const defaultCheckoutProvider = envString('DEFAULT_CHECKOUT_PROVIDER', 'toss').toLowerCase();

  return {
    backendRoot,
    port: envNumber('PORT', 8787),
    publicBaseUrl,
    databasePath: resolvePath(envString('DATABASE_PATH', './data/chargecat.sqlite')),
    lemonApiKey: envString('LEMON_API_KEY'),
    lemonWebhookSecret: envString('LEMON_WEBHOOK_SECRET'),
    lemonStoreId: envNumber('LEMON_STORE_ID', 0),
    lemonProductId: envNumber('LEMON_PRODUCT_ID', 0),
    lemonVariantId: envNumber('LEMON_VARIANT_ID', 0),
    tossWidgetClientKey: envString('TOSS_WIDGET_CLIENT_KEY'),
    tossSecretKey: envString('TOSS_SECRET_KEY'),
    tossWidgetVariantKey: envString('TOSS_WIDGET_VARIANT_KEY', 'DEFAULT'),
    proPriceKrw: envNumber('PRO_PRICE_KRW', 3900),
    defaultCheckoutProvider: defaultCheckoutProvider === 'lemon' ? 'lemon' : 'toss',
    appCustomScheme,
    myOrdersUrl: envUrl('MY_ORDERS_URL', 'https://app.lemonsqueezy.com/my-orders'),
    supportUrl: envUrl('SUPPORT_URL', 'https://github.com/coldmans/chargeCat/issues'),
    appDownloadUrl: envUrl('APP_DOWNLOAD_URL', 'https://github.com/coldmans/chargeCat/releases'),
    productName: envString('PRODUCT_NAME', 'Charge Cat Pro'),
    get isLemonConfigured() {
      return Boolean(
        this.publicBaseUrl &&
        this.lemonApiKey &&
        this.lemonWebhookSecret &&
        this.lemonStoreId > 0 &&
        this.lemonProductId > 0 &&
        this.lemonVariantId > 0
      );
    },
    get isTossConfigured() {
      return Boolean(
        this.publicBaseUrl &&
        this.tossWidgetClientKey &&
        this.tossSecretKey &&
        this.proPriceKrw > 0
      );
    },
    get hasCheckoutProvider() {
      return this.isTossConfigured || this.isLemonConfigured;
    }
  };
}
