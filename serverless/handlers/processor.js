// kk-processor: fires when a receipt-*.json lands in the receipts bucket
// (from kk-payments in Kubernetes, or from generateReceipt). Writes processed-<orderId>.json.
const { putJson, getJson, orderIdFromKey, log } = require('./s3');

module.exports.processReceiptUpload = async (event) => {
  for (const record of event.Records) {
    const bucketName = record.s3.bucket.name;
    const objectKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    const orderId = orderIdFromKey(objectKey, 'receipt-');
    const base = { service: 'kk-processor', orderId, bucketName, objectKey, fileSizeBytes: record.s3.object.size, uploadedAt: record.eventTime };

    if (orderId === 'UNKNOWN') {
      log({ ...base, event: 'receipt.skipped', warning: 'malformed key: could not extract orderId' });
      continue;
    }
    const receipt = await getJson(bucketName, objectKey);
    const processed = { orderId, amount: receipt.amount, currency: receipt.currency, sourceKey: objectKey, processingTimestamp: new Date().toISOString() };
    await putJson(process.env.OUTPUT_BUCKET, `processed-${orderId}.json`, processed);
    log({ ...base, event: 'receipt.processed', amount: receipt.amount, source: receipt.source || 'unknown' });
  }
};
