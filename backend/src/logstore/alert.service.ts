import { Injectable, Logger } from '@nestjs/common';
import { EventEnvelope } from '../common/event-envelope';

/**
 * Discord-Alerts für sicherheitsrelevante Events (Team-Channel).
 * Optional: ohne DISCORD_WEBHOOK_URL komplett inaktiv.
 * Throttle pro Event-Typ verhindert Webhook-Rate-Limits bei Alert-Stürmen.
 */
@Injectable()
export class AlertService {
  private readonly logger = new Logger(AlertService.name);
  private readonly webhookUrl = process.env.DISCORD_WEBHOOK_URL ?? '';
  private readonly lastSent = new Map<string, number>();

  private static readonly ALERTS: Record<string, { title: string; color: number; throttleMs: number }> = {
    'security.anticheat': { title: '🛡 Anti-Cheat-Detection', color: 0xef4444, throttleMs: 60000 },
    'security.ban': { title: '🔨 Ban ausgesprochen', color: 0x991b1b, throttleMs: 0 },
    'anomaly.detected': { title: '📊 Anomalie erkannt', color: 0xf59e0b, throttleMs: 0 },
    'system.error': { title: '💥 Server-Fehler', color: 0x7c3aed, throttleMs: 300000 },
  };

  async checkBatch(events: EventEnvelope[]): Promise<void> {
    if (!this.webhookUrl) return;
    for (const event of events) {
      const alert = AlertService.ALERTS[event.type];
      if (!alert) continue;

      const last = this.lastSent.get(event.type) ?? 0;
      if (alert.throttleMs > 0 && Date.now() - last < alert.throttleMs) continue;
      this.lastSent.set(event.type, Date.now());

      await this.send(alert.title, alert.color, event);
    }
  }

  private async send(title: string, color: number, event: EventEnvelope): Promise<void> {
    try {
      const fields = [
        event.actor?.accountId && { name: 'Account', value: String(event.actor.accountId), inline: true },
        event.actor?.characterId && { name: 'Charakter', value: String(event.actor.characterId), inline: true },
        { name: 'Details', value: '```json\n' + JSON.stringify(event.payload).slice(0, 900) + '\n```' },
      ].filter(Boolean);

      await fetch(this.webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          embeds: [{
            title, color, fields,
            footer: { text: `${event.type} · ${event.serverId}` },
            timestamp: new Date(event.ts).toISOString(),
          }],
        }),
      });
    } catch (err) {
      this.logger.warn(`Discord-Alert fehlgeschlagen: ${(err as Error).message}`);
    }
  }
}
