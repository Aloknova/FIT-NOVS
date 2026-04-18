import 'dotenv/config';
import cors from 'cors';
import express from 'express';

import { adminRouter } from './routes/admin.js';
import { aiRouter } from './routes/ai.js';
import { socialRouter } from './routes/social.js';
import { supabaseProxyRouter } from './routes/supabase_proxy.js';

const app = express();
const port = Number(process.env.PORT ?? 8080);

app.use(cors());
app.use('/supabase', supabaseProxyRouter);
app.use(express.json({ limit: '2mb' }));

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    service: 'smart-ai-fitness-backend',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/ai', aiRouter);
app.use('/api/admin', adminRouter);
app.use('/api/social', socialRouter);

app.listen(port, () => {
  console.log(`AI gateway listening on port ${port}`);
});
