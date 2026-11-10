// kk-receipts: HTTP entry point. Writes receipt-<orderId>.json into the receipts bucket,
// the same bucket and key format kk-payments uses from Kubernetes, so both start the same chain.
const { putJson, log } = require('./s3');

module.exports.generateReceipt = async (event) => {
  let body;
  try { body = JSON.parse(event.body || '{}'); } catch { return { statusCode: 400, body: JSON.stringify({ error: 'invalid JSON' }) }; }
  if (!body.orderId) return { statusCode: 400, body: JSON.stringify({ error: 'orderId is required' }) };

  const receipt = {
    receiptId: `RCPT-${Date.now()}`,
    orderId: body.orderId,
    amount: body.amount,
    currency: body.currency || process.env.DEFAULT_CURRENCY,
    source: 'http',
    createdAt: new Date().toISOString(),
  };
  const key = `receipt-${body.orderId}.json`;
  await putJson(process.env.OUTPUT_BUCKET, key, receipt);
  log({ service: 'kk-receipts', event: 'receipt.generated', orderId: receipt.orderId, bucketName: process.env.OUTPUT_BUCKET, objectKey: key });
  return { statusCode: 200, body: JSON.stringify({ receiptId: receipt.receiptId, orderId: receipt.orderId, status: 'queued' }) };
};
