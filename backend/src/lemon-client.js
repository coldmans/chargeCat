function ensureConfigured(config) {
  if (!config.isLemonConfigured) {
    throw new Error('Lemon Squeezy backend config is incomplete.');
  }
}

function jsonApiHeaders(config) {
  return {
    Accept: 'application/vnd.api+json',
    'Content-Type': 'application/vnd.api+json',
    Authorization: `Bearer ${config.lemonApiKey}`
  };
}

async function parseJson(response) {
  const text = await response.text();
  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Lemon returned non-JSON data (${response.status}).`);
  }
}

export class LemonClient {
  constructor(config) {
    this.config = config;
  }

  async createAppCheckout({ sessionId, installationId, customerEmail, source }) {
    return this.createCheckout({
      customerEmail,
      customData: {
        session_id: sessionId,
        installation_id: installationId,
        source
      },
      redirectUrl: `${this.config.publicBaseUrl.toString().replace(/\/$/, '')}/checkout/return?session_id=${encodeURIComponent(sessionId)}`,
      receiptButtonText: 'Open Charge Cat',
      receiptLinkUrl: `${this.config.publicBaseUrl.toString().replace(/\/$/, '')}/checkout/return?session_id=${encodeURIComponent(sessionId)}`
    });
  }

  async createWebsiteCheckout({ customerEmail }) {
    return this.createCheckout({
      customerEmail,
      customData: {
        source: 'web'
      },
      redirectUrl: `${this.config.publicBaseUrl.toString().replace(/\/$/, '')}/checkout/thanks`,
      receiptButtonText: 'Open My Orders',
      receiptLinkUrl: this.config.myOrdersUrl?.toString() ?? 'https://app.lemonsqueezy.com/my-orders'
    });
  }

  async createCheckout({ customerEmail, customData, redirectUrl, receiptButtonText, receiptLinkUrl }) {
    ensureConfigured(this.config);

    const response = await fetch('https://api.lemonsqueezy.com/v1/checkouts', {
      method: 'POST',
      headers: jsonApiHeaders(this.config),
      body: JSON.stringify({
        data: {
          type: 'checkouts',
          attributes: {
            product_options: {
              redirect_url: redirectUrl,
              receipt_button_text: receiptButtonText,
              receipt_link_url: receiptLinkUrl
            },
            checkout_data: {
              email: customerEmail,
              custom: customData
            }
          },
          relationships: {
            store: {
              data: {
                type: 'stores',
                id: String(this.config.lemonStoreId)
              }
            },
            variant: {
              data: {
                type: 'variants',
                id: String(this.config.lemonVariantId)
              }
            }
          }
        }
      })
    });

    const payload = await parseJson(response);
    if (!response.ok) {
      const message = payload?.errors?.[0]?.detail || payload?.message || `Lemon checkout creation failed (${response.status}).`;
      throw new Error(message);
    }

    const checkout = payload?.data;
    const checkoutUrl = checkout?.attributes?.url;
    if (!checkout?.id || !checkoutUrl) {
      throw new Error('Lemon checkout response was incomplete.');
    }

    return {
      id: String(checkout.id),
      url: checkoutUrl
    };
  }

  async validateLicense({ licenseKey, instanceId }) {
    ensureConfigured(this.config);

    const body = new URLSearchParams();
    body.set('license_key', licenseKey);
    if (instanceId) {
      body.set('instance_id', instanceId);
    }

    const response = await fetch('https://api.lemonsqueezy.com/v1/licenses/validate', {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body.toString()
    });

    const payload = await parseJson(response);
    if (!response.ok) {
      const message = payload?.error || payload?.message || `Lemon license validation failed (${response.status}).`;
      throw new Error(message);
    }

    return payload;
  }
}
