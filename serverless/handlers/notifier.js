// kk-notifier: fires when processed-*.json lands in the processor bucket.
// "Sends" the notification by logging it, and keeps a copy in the notifications bucket.
const { putJson, orderIdFromKey, log } = require('./s3');

module.exports.notifyReceipt = async (event) => {
  for (const record of event.Records) {
    const objectKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    const orderId = orderIdFromKey(objectKey, 'processed-');
    const entry = { service: 'kk-notifier', event: 'notification.dispatched', orderId, channel: process.env.NOTIFICATION_CHANNEL, sourceKey: objectKey, dispatchedAt: new Date().toISOString() };
    await putJson(process.env.OUTPUT_BUCKET, `notify-${orderId}.json`, entry);
    log(entry);
  }
};
