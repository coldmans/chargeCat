function ensureConfigured(config) {
  if (!config.isTossConfigured) {
    throw new Error('Toss Payments backend config is incomplete.');
  }
}

async function parseJson(response) {
  const text = await response.text();
  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Toss returned non-JSON data (${response.status}).`);
  }
}

function basicAuthHeader(secretKey) {
  return `Basic ${Buffer.from(`${secretKey}:`).toString('base64')}`;
}

export class TossAPIError extends Error {
  constructor({ message, code, status }) {
    super(message);
    this.name = 'TossAPIError';
    this.code = code ?? null;
    this.status = status;
  }
}

export class TossClient {
  constructor(config) {
    this.config = config;
  }

  async confirmPayment({ paymentKey, orderId, amount }) {
    return this.request('/v1/payments/confirm', {
      method: 'POST',
      body: JSON.stringify({
        paymentKey,
        orderId,
        amount
      })
    });
  }

  async getPaymentByOrderId(orderId) {
    return this.request(`/v1/payments/orders/${encodeURIComponent(orderId)}`, {
      method: 'GET'
    });
  }

  async request(path, { method, body }) {
    ensureConfigured(this.config);

    const response = await fetch(`https://api.tosspayments.com${path}`, {
      method,
      headers: {
        Accept: 'application/json',
        'Accept-Language': 'en',
        Authorization: basicAuthHeader(this.config.tossSecretKey),
        ...(body ? { 'Content-Type': 'application/json' } : {})
      },
      body
    });

    const payload = await parseJson(response);
    if (response.ok === false) {
      throw new TossAPIError({
        message: payload?.message || `Toss request failed (${response.status}).`,
        code: payload?.code || null,
        status: response.status
      });
    }

    return payload;
  }
}
