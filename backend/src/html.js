function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function formatCurrency(value) {
  return new Intl.NumberFormat('ko-KR', {
    style: 'currency',
    currency: 'KRW',
    maximumFractionDigits: 0
  }).format(Number(value) || 0);
}

function serializeForScript(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

function pageTemplate({ title, body }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #2e2621;
      --cream: #fcf7f0;
      --amber: #ed9e4f;
      --coral: #e3755f;
      --paper: #fffdf9;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 24px;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
      background:
        radial-gradient(circle at top right, rgba(237,158,79,0.18), transparent 35%),
        radial-gradient(circle at bottom left, rgba(227,117,95,0.14), transparent 30%),
        var(--cream);
      color: var(--ink);
    }
    .card {
      width: min(560px, 100%);
      background: rgba(255,255,255,0.92);
      border: 1px solid rgba(46,38,33,0.08);
      border-radius: 24px;
      padding: 28px;
      box-shadow: 0 20px 60px rgba(46,38,33,0.10);
    }
    h1 {
      margin: 0 0 12px;
      font-size: clamp(28px, 5vw, 40px);
      line-height: 1.05;
      letter-spacing: -0.03em;
    }
    p {
      margin: 0 0 16px;
      font-size: 15px;
      line-height: 1.6;
      color: rgba(46,38,33,0.76);
    }
    .actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      margin-top: 20px;
    }
    .btn {
      appearance: none;
      border: 0;
      text-decoration: none;
      border-radius: 14px;
      padding: 13px 18px;
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
    }
    .btn-primary {
      color: white;
      background: linear-gradient(135deg, var(--amber), var(--coral));
    }
    .btn-secondary {
      color: var(--ink);
      background: var(--paper);
      border: 1px solid rgba(46,38,33,0.10);
    }
    .meta {
      margin-top: 18px;
      font-size: 13px;
      color: rgba(46,38,33,0.52);
    }
  </style>
</head>
<body>
  <main class="card">
    ${body}
  </main>
</body>
</html>`;
}

export function renderCheckoutReturnPage({
  appOpenUrl,
  myOrdersUrl,
  secondaryLabel = 'Open My Orders',
  title = 'Open Charge Cat',
  heading = 'Charge Cat is finishing your unlock.',
  description = 'Your payment went through. If Charge Cat is installed, this page will try to reopen the app and finish activation automatically.'
}) {
  const safeOpenUrl = escapeHtml(appOpenUrl);
  const safeOrdersUrl = escapeHtml(myOrdersUrl);

  return pageTemplate({
    title,
    body: `
      <h1>${escapeHtml(heading)}</h1>
      <p>${escapeHtml(description)}</p>
      <div class="actions">
        <a class="btn btn-primary" href="${safeOpenUrl}">Open Charge Cat</a>
        <a class="btn btn-secondary" href="${safeOrdersUrl}">${escapeHtml(secondaryLabel)}</a>
      </div>
      <p class="meta">If the app does not open automatically, click “Open Charge Cat”.</p>
      <script>
        window.setTimeout(function () {
          window.location.href = ${JSON.stringify(appOpenUrl)};
        }, 150);
      </script>
    `
  });
}

export function renderCheckoutThanksPage({
  appDownloadUrl,
  myOrdersUrl,
  secondaryLabel = 'Open My Orders',
  title = 'Thanks for buying Charge Cat Pro',
  heading = 'Thanks for buying Charge Cat Pro.',
  description = 'Your order is complete. If you bought from the website, you can always find your license in My Orders. If you install Charge Cat later, the app can use that purchase from there.',
  licenseKey,
  customerEmail
}) {
  const licenseBlock = licenseKey
    ? `
      <div style="margin-top:20px;padding:16px 18px;border-radius:18px;background:#fff7ee;border:1px solid rgba(46,38,33,0.08);">
        <div style="font-size:12px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:rgba(46,38,33,0.52);margin-bottom:8px;">Your Pro license</div>
        <div style="font:600 18px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;word-break:break-all;">${escapeHtml(licenseKey)}</div>
        <div style="margin-top:10px;font-size:13px;color:rgba(46,38,33,0.58);">
          ${customerEmail ? `Issued for ${escapeHtml(customerEmail)}. ` : ''}
          If Charge Cat is already installed, you can also paste this into the app manually.
        </div>
      </div>
    `
    : '';

  return pageTemplate({
    title,
    body: `
      <h1>${escapeHtml(heading)}</h1>
      <p>${escapeHtml(description)}</p>
      ${licenseBlock}
      <div class="actions">
        <a class="btn btn-primary" href="${escapeHtml(appDownloadUrl)}">Download Charge Cat</a>
        <a class="btn btn-secondary" href="${escapeHtml(myOrdersUrl)}">${escapeHtml(secondaryLabel)}</a>
      </div>
    `
  });
}

export function renderTossCheckoutPage({
  clientKey,
  variantKey,
  customerKey,
  orderId,
  orderName,
  amount,
  customerEmail,
  successUrl,
  failUrl,
  supportUrl
}) {
  return pageTemplate({
    title: 'Charge Cat Pro Checkout',
    body: `
      <h1>Unlock Charge Cat Pro</h1>
      <p>Finish your payment below and Charge Cat will unlock automatically when possible.</p>
      <div style="display:flex;justify-content:space-between;gap:12px;align-items:flex-start;padding:16px 18px;border-radius:18px;background:#fff7ee;border:1px solid rgba(46,38,33,0.08);margin-bottom:18px;">
        <div>
          <div style="font-weight:700;">${escapeHtml(orderName)}</div>
          <div style="margin-top:6px;font-size:13px;color:rgba(46,38,33,0.58);">${customerEmail ? escapeHtml(customerEmail) : 'Charge Cat Pro lifetime unlock'}</div>
        </div>
        <div style="font-size:22px;font-weight:800;letter-spacing:-0.03em;">${escapeHtml(formatCurrency(amount))}</div>
      </div>
      <div id="payment-method" style="min-height:284px;border-radius:18px;background:rgba(255,255,255,0.84);border:1px solid rgba(46,38,33,0.08);padding:10px;"></div>
      <div id="agreement" style="margin-top:12px;"></div>
      <div class="actions">
        <button id="pay-button" class="btn btn-primary" type="button">Pay Now</button>
        <a class="btn btn-secondary" href="${escapeHtml(supportUrl)}">Need Help?</a>
      </div>
      <p id="status-text" class="meta">Card and easy-pay methods usually unlock right away. Deposit-based methods can take longer.</p>
      <script src="https://js.tosspayments.com/v2/standard"></script>
      <script>
        const checkoutConfig = {
          clientKey: ${serializeForScript(clientKey)},
          variantKey: ${serializeForScript(variantKey)},
          customerKey: ${serializeForScript(customerKey)},
          amount: ${Number(amount) || 0},
          orderId: ${serializeForScript(orderId)},
          orderName: ${serializeForScript(orderName)},
          customerEmail: ${serializeForScript(customerEmail || '')},
          successUrl: ${serializeForScript(successUrl)},
          failUrl: ${serializeForScript(failUrl)}
        };

        const statusText = document.getElementById('status-text');
        const payButton = document.getElementById('pay-button');

        async function mountCheckout() {
          const tossPayments = TossPayments(checkoutConfig.clientKey);
          const widgets = tossPayments.widgets({
            customerKey: checkoutConfig.customerKey
          });

          await widgets.setAmount({
            value: checkoutConfig.amount,
            currency: 'KRW'
          });

          await widgets.renderPaymentMethods({
            selector: '#payment-method',
            variantKey: checkoutConfig.variantKey
          });

          await widgets.renderAgreement({
            selector: '#agreement'
          });

          payButton.addEventListener('click', async function () {
            payButton.disabled = true;
            payButton.textContent = 'Opening payment window...';
            statusText.textContent = 'Securely opening Toss Payments...';

            try {
              await widgets.requestPayment({
                orderId: checkoutConfig.orderId,
                orderName: checkoutConfig.orderName,
                successUrl: checkoutConfig.successUrl,
                failUrl: checkoutConfig.failUrl,
                customerEmail: checkoutConfig.customerEmail || undefined
              });
            } catch (error) {
              payButton.disabled = false;
              payButton.textContent = 'Pay Now';
              statusText.textContent = error && error.message ? error.message : 'Could not start the payment flow.';
            }
          });
        }

        mountCheckout().catch(function (error) {
          payButton.disabled = true;
          statusText.textContent = error && error.message ? error.message : 'Could not load Toss Payments.';
        });
      </script>
    `
  });
}

export function renderCheckoutFailurePage({
  title,
  heading,
  description,
  retryUrl,
  supportUrl,
  openAppUrl,
  errorCode,
  errorMessage
}) {
  const meta = [errorCode, errorMessage].filter(Boolean).map((value) => escapeHtml(value)).join(' · ');
  const appAction = openAppUrl
    ? `<a class="btn btn-secondary" href="${escapeHtml(openAppUrl)}">Open Charge Cat</a>`
    : `<a class="btn btn-secondary" href="${escapeHtml(supportUrl)}">Need Help?</a>`;

  return pageTemplate({
    title,
    body: `
      <h1>${escapeHtml(heading)}</h1>
      <p>${escapeHtml(description)}</p>
      <div class="actions">
        <a class="btn btn-primary" href="${escapeHtml(retryUrl)}">Try Again</a>
        ${appAction}
      </div>
      ${meta ? `<p class="meta">${meta}</p>` : ''}
    `
  });
}

export function renderCheckoutPendingPage({
  title,
  heading,
  description,
  refreshUrl,
  supportUrl,
  openAppUrl
}) {
  const secondaryAction = openAppUrl
    ? `<a class="btn btn-secondary" href="${escapeHtml(openAppUrl)}">Open Charge Cat</a>`
    : `<a class="btn btn-secondary" href="${escapeHtml(supportUrl)}">Need Help?</a>`;

  return pageTemplate({
    title,
    body: `
      <h1>${escapeHtml(heading)}</h1>
      <p>${escapeHtml(description)}</p>
      <div class="actions">
        <a class="btn btn-primary" href="${escapeHtml(refreshUrl)}">Refresh Status</a>
        ${secondaryAction}
      </div>
      <p class="meta">Charge Cat will unlock as soon as the payment is confirmed.</p>
    `
  });
}
