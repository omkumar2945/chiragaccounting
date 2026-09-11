import express from 'express';
import cors from 'cors';

import { errorHandler } from './middleware/errorHandler.js';
import authRoutes from './routes/auth.js';

export const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});
app.get('/', (_req, res) => {
  res.json({ message: 'Chirag Accounting API Running' });
});
app.use('/api/auth', authRoutes);
app.use(errorHandler);
