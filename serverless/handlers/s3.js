// Shared S3 client. Locally it talks to serverless-s3-local; in AWS, S3_ENDPOINT is unset.
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');

const s3 = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  endpoint: process.env.S3_ENDPOINT || undefined,
  forcePathStyle: true,
  credentials: process.env.S3_ENDPOINT
    ? { accessKeyId: 'S3RVER', secretAccessKey: 'S3RVER' }   // serverless-s3-local's fixed local credentials
    : undefined,
});

async function putJson(bucket, key, obj) {
  await s3.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: JSON.stringify(obj), ContentType: 'application/json' }));
}

async function getJson(bucket, key) {
  const res = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  return JSON.parse(await res.Body.transformToString());
}

// receipt-ORD-1.json -> ORD-1 ; anything that does not match -> "UNKNOWN"
function orderIdFromKey(key, prefix) {
  const m = key.match(new RegExp(`^${prefix}(.+)\\.json$`));
  return m ? m[1] : 'UNKNOWN';
}

const log = (entry) => console.log(JSON.stringify(entry));

module.exports = { putJson, getJson, orderIdFromKey, log };
