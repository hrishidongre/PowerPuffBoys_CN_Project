const express = require('express');
const app = express();

const PORT = 3001;
const BACKEND = 'A';
const ETAG_VALUE = '"backend-a-v1"';

app.use(express.json());

// Set X-Backend header on every response
app.use((req, res, next) => {
  res.setHeader('X-Backend', BACKEND);
  next();
});

// Required: GET / — with caching headers + conditional request support
app.get('/', (req, res) => {
  res.setHeader('Cache-Control', 'max-age=60');
  res.setHeader('ETag', ETAG_VALUE);

  // Check if client's cached copy is still valid
  if (req.headers['if-none-match'] === ETAG_VALUE) {
    return res.status(304).end();  // No body — tells client to reuse its cache
  }

  res.send(`<h1>Backend ${BACKEND} running</h1><p>Service is up.</p>`);
});

// Required: GET /api/status
app.get('/api/status', (req, res) => {
  res.status(200).json({ backend: BACKEND, status: 'ok' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend ${BACKEND} running on http://0.0.0.0:${PORT}`);
});