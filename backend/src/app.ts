import express from 'express';
import cors from 'cors';

import { errorHandler } from './middleware/errorHandler.js';
import { verifyToken } from './middleware/auth.js';
import authRoutes from './routes/auth.js';
import { clientDataRoutes } from './routes/clientDataRoutes.js';
import { gstComplianceRoutes } from './routes/gstComplianceRoutes.js';
import { gstZenRoutes } from './routes/gstZenRoutes.js';
import { locationRoutes } from './routes/locationRoutes.js';

export const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});
app.get('/', (_req, res) => {
  res.json({ message: 'Chirag Accounting API Running' });
});
app.use('/v1', authRoutes);
app.use('/api', authRoutes);
app.use('/v1', clientDataRoutes());
app.use('/api', clientDataRoutes());
app.use('/v1', verifyToken, gstZenRoutes());
app.use('/api', verifyToken, gstZenRoutes());
app.use('/v1', verifyToken, gstComplianceRoutes());
app.use('/api', verifyToken, gstComplianceRoutes());
app.use('/v1', locationRoutes());
app.use('/api', locationRoutes());
app.use(errorHandler);
