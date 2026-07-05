import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  // Batches können groß werden (100 Events + Payloads)
  app.use(require('express').json({ limit: '5mb' }));

  // OpenAPI unter /api-docs (abschaltbar via API_DOCS=0)
  if (process.env.API_DOCS !== '0') {
    const config = new DocumentBuilder()
      .setTitle('HardcoreRP Backend')
      .setDescription('Ingest-, Auth-, UCP- und ACP-API. Log-Event-Katalog: docs/log-event-catalog.md')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('api-docs', app, SwaggerModule.createDocument(app, config));
  }

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`[hrp-backend] listening on :${port}`);
}

void bootstrap();
