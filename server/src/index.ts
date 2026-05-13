import express from 'express';
import cors from 'cors';
import { authRouter } from './routes/auth';
import { categoryRouter } from './routes/categories';
import { transactionRouter } from './routes/transactions';
import { statsRouter } from './routes/stats';
import { importRouter } from './routes/import';
import { exportRouter } from './routes/export';
import { syncRouter } from './routes/sync';
import { errorHandler } from './middleware/errorHandler';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.use('/api/auth', authRouter);
app.use('/api/categories', categoryRouter);
app.use('/api/transactions', transactionRouter);
app.use('/api/stats', statsRouter);
app.use('/api/import', importRouter);
app.use('/api/export', exportRouter);
app.use('/api/sync', syncRouter);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
