import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';

import { loadConfig } from './config.js';
import { assetDownloadRequestSchema } from './validators.js';

function baseUrlString(config, request) {
  const configured = config.publicBaseUrl?.toString().replace(/\/$/, '');
  if (configured) {
    return configured;
  }

  return `${request.protocol}://${request.get('host')}`.replace(/\/$/, '');
}

function publicUrl(config, request, pathname) {
  return `${baseUrlString(config, request)}${pathname.startsWith('/') ? pathname : `/${pathname}`}`;
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

function loadAssetCatalog(config, request) {
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
    const downloadURL = filename
      ? publicUrl(config, request, `/api/assets/download/${encodeURIComponent(id)}`)
      : sourceDownloadURL;

    return [{
      id,
      title,
      mediaType,
      downloadURL,
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

function findAssetById(config, request, assetId) {
  return loadAssetCatalog(config, request).find((asset) => asset.id === assetId) ?? null;
}

export function createApp(config = loadConfig()) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', true);

  app.get('/healthz', (request, response) => {
    let assetCount = 0;
    try {
      assetCount = loadAssetCatalog(config, request).length;
    } catch {
      assetCount = 0;
    }

    response.json({
      ok: true,
      assetCount
    });
  });

  app.get('/api/assets/catalog', (request, response) => {
    try {
      response.json({
        assets: loadAssetCatalog(config, request).map(serializeAssetForClient)
      });
    } catch (error) {
      response.status(500).json({
        error: error instanceof Error ? error.message : 'Could not load the asset catalog.'
      });
    }
  });

  app.get('/api/assets/download/:assetId', async (request, response) => {
    const parsed = assetDownloadRequestSchema.safeParse({
      assetId: request.params.assetId
    });

    if (!parsed.success) {
      response.status(400).json({
        error: 'Invalid asset request.'
      });
      return;
    }

    const asset = findAssetById(config, request, parsed.data.assetId);
    if (!asset) {
      response.status(404).json({
        error: 'Asset not found.'
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

    response.redirect(asset.sourceDownloadURL);
  });

  return app;
}

const isDirectRun = process.argv[1] &&
  fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);

if (isDirectRun) {
  const config = loadConfig();
  createApp(config).listen(config.port);
}
