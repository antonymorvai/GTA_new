import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  // Batches können groß werden (100 Events + Payloads)
  app.use(require('express').json({ limit: '5mb' }));
  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`[hrp-backend] listening on :${port}`);
}

void bootstrap();
