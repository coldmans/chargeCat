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
  return {
    backendRoot,
    port: envNumber('PORT', 8787),
    publicBaseUrl: envUrl('PUBLIC_BASE_URL'),
    assetCatalogPath: resolvePath(envString('ASSET_CATALOG_PATH', './assets/catalog.json')),
    assetFilesPath: resolvePath(envString('ASSET_FILES_PATH', './assets/files')),
    supportUrl: envUrl('SUPPORT_URL', 'https://github.com/coldmans/chargeCat/issues'),
    appDownloadUrl: envUrl('APP_DOWNLOAD_URL', 'https://github.com/coldmans/chargeCat/releases')
  };
}
