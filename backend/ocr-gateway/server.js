import crypto from 'node:crypto';
import express from 'express';
import {v1} from '@google-cloud/documentai';

const app = express();
const port = Number(process.env.PORT || 8080);
const processorId = process.env.DOCUMENT_AI_PROCESSOR_ID;
const projectId = process.env.GOOGLE_CLOUD_PROJECT;
const location = process.env.DOCUMENT_AI_LOCATION || 'us';
const gatewayToken = process.env.OCR_GATEWAY_TOKEN;
const endpoint = location === 'us' ? 'us-documentai.googleapis.com' : `${location}-documentai.googleapis.com`;

app.disable('x-powered-by');
app.use(express.json({limit: '21mb', strict: true}));

const client = new v1.DocumentProcessorServiceClient({apiEndpoint: endpoint});

function unauthorized(req) {
  const supplied = (req.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!gatewayToken || supplied.length !== gatewayToken.length) return true;
  return !crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(gatewayToken));
}

function entity(document, type) {
  return document.entities?.find((item) => item.type === type);
}

function safeDate(candidate) {
  if (!candidate) return null;
  const value = candidate.normalizedValue?.dateValue || candidate.normalizedValue?.text || candidate.mentionText;
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  const date = value && typeof value === 'object'
    ? `${value.year}-${String(value.month).padStart(2, '0')}-${String(value.day).padStart(2, '0')}`
    : null;
  return date && !date.startsWith('0-') ? date : null;
}

app.get('/health', (_req, res) => res.json({ok: true}));

app.post('/v1/receipt:analyze', async (req, res) => {
  if (unauthorized(req)) return res.status(401).json({message: 'Servicio OCR no autorizado.'});
  if (!processorId || !projectId) return res.status(503).json({message: 'El servicio OCR aún no está configurado.'});

  const {mimeType, contentBase64} = req.body || {};
  const allowedMimeTypes = new Set(['application/pdf', 'image/jpeg', 'image/png']);
  if (!allowedMimeTypes.has(mimeType) || typeof contentBase64 !== 'string') {
    return res.status(400).json({message: 'Formato de comprobante no admitido.'});
  }

  let content;
  try {
    content = Buffer.from(contentBase64, 'base64');
  } catch {
    return res.status(400).json({message: 'No se pudo leer el archivo enviado.'});
  }
  if (content.length === 0 || content.length > 15 * 1024 * 1024) {
    return res.status(413).json({message: 'El archivo debe pesar hasta 15 MB.'});
  }

  try {
    const name = `projects/${projectId}/locations/${location}/processors/${processorId}`;
    const [result] = await client.processDocument({
      name,
      rawDocument: {content, mimeType},
    });
    const document = result.document || {};
    const supplier = entity(document, 'supplier_name');
    const total = entity(document, 'total_amount');
    const currencyEntity = entity(document, 'currency');
    const receiptDate = entity(document, 'receipt_date');
    const money = total?.normalizedValue?.moneyValue;
    const units = Number(money?.units || 0);
    const nanos = Number(money?.nanos || 0);
    const amountCents = Number.isFinite(units) && Number.isFinite(nanos)
      ? Math.round(units * 100 + nanos / 10_000_000)
      : null;
    const currency = money?.currencyCode || currencyEntity?.normalizedValue?.text || null;
    const confidences = [supplier?.confidence, total?.confidence, receiptDate?.confidence]
      .filter((value) => typeof value === 'number');

    return res.json({
      merchant: supplier?.normalizedValue?.text || supplier?.mentionText || null,
      amountCents: amountCents > 0 ? amountCents : null,
      currency,
      date: safeDate(receiptDate),
      confidence: confidences.length
        ? confidences.reduce((sum, value) => sum + value, 0) / confidences.length
        : null,
    });
  } catch (error) {
    console.error('Document AI processing failed:', error?.code || 'unknown');
    return res.status(502).json({message: 'Google Document AI no pudo procesar el comprobante.'});
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`OCR gateway listening on ${port}`);
});
