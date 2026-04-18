import express from 'express';

const supabaseProxyRouter = express.Router();

supabaseProxyRouter.use(
  express.raw({
    type: '*/*',
    limit: '10mb',
  }),
);

supabaseProxyRouter.all('*', async (request, response) => {
  const supabaseUrl = process.env.SUPABASE_URL;

  if (!supabaseUrl) {
    response.status(500).json({
      error: 'SUPABASE_URL is required for the local Supabase proxy.',
    });
    return;
  }

  const targetPath = request.originalUrl.replace(/^\/supabase/, '');
  const targetUrl = new URL(targetPath, supabaseUrl);

  try {
    const headers = new Headers();

    for (const [key, value] of Object.entries(request.headers)) {
      if (value == null) {
        continue;
      }

      if (
        key === 'host' ||
        key === 'connection' ||
        key === 'content-length'
      ) {
        continue;
      }

      headers.set(key, Array.isArray(value) ? value.join(', ') : value);
    }

    const method = request.method.toUpperCase();
    const upstreamResponse = await fetch(targetUrl, {
      method,
      headers,
      redirect: 'manual',
      body:
          method == 'GET' || method == 'HEAD' || request.body?.length == null
              ? undefined
              : request.body,
    });

    response.status(upstreamResponse.status);

    upstreamResponse.headers.forEach((value, key) => {
      if (
        key === 'content-encoding' ||
        key === 'content-length' ||
        key === 'connection' ||
        key === 'transfer-encoding'
      ) {
        return;
      }

      response.setHeader(key, value);
    });

    const buffer = Buffer.from(await upstreamResponse.arrayBuffer());

    if (buffer.length == 0) {
      response.end();
      return;
    }

    response.send(buffer);
  } catch (error) {
    console.error('Supabase proxy request failed.', error);
    response.status(502).json({
      error: 'Could not reach Supabase through the local proxy.',
      details: error instanceof Error ? error.message : 'Unknown proxy error.',
    });
  }
});

export { supabaseProxyRouter };
