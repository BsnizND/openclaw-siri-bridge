import { describe, expect, it } from 'vitest';
import { loadConfig, parseAllowedSources } from '../src/config.js';

describe('config', () => {
  it('parses allowed sources', () => {
    expect([...parseAllowedSources('siri_watch, siri_iphone,,shortcuts')]).toEqual([
      'siri_watch',
      'siri_iphone',
      'shortcuts'
    ]);
  });

  it('requires a long bridge token', () => {
    expect(() => loadConfig({ SIRI_BRIDGE_TOKEN: 'short' })).toThrow('SIRI_BRIDGE_TOKEN');
  });

  it('requires HTTP ingest credentials when HTTP adapter is selected', () => {
    expect(() =>
      loadConfig({
        SIRI_BRIDGE_TOKEN: '0123456789abcdef01234567',
        OPENCLAW_ADAPTER: 'http'
      })
    ).toThrow('OPENCLAW_INGEST_URL and OPENCLAW_INGEST_TOKEN');
  });

  it('loads defaults for a CLI deployment', () => {
    const config = loadConfig({ SIRI_BRIDGE_TOKEN: '0123456789abcdef01234567' });
    expect(config.port).toBe(8788);
    expect(config.assistantId).toBe('jay');
    expect(config.allowedSources.has('siri_watch')).toBe(true);
    expect(config.openclawAdapter).toBe('cli');
    expect(config.openclawDeliverReply).toBe(false);
    expect(config.openclawMessageStyle).toBe('detailed');
  });

  it('requires reply routing when OpenClaw delivery is enabled', () => {
    expect(() =>
      loadConfig({
        SIRI_BRIDGE_TOKEN: '0123456789abcdef01234567',
        OPENCLAW_DELIVER_REPLY: 'true'
      })
    ).toThrow('OPENCLAW_REPLY_CHANNEL and OPENCLAW_REPLY_TO');
  });

  it('loads Telegram direct reply routing', () => {
    const config = loadConfig({
      SIRI_BRIDGE_TOKEN: '0123456789abcdef01234567',
      OPENCLAW_DELIVER_REPLY: 'true',
      OPENCLAW_REPLY_CHANNEL: 'telegram',
      OPENCLAW_REPLY_TO: 'telegram:1234',
      OPENCLAW_MESSAGE_STYLE: 'compact',
      SIRI_MESSAGE_PREFIX: 'Sent via Apple Watch voice message:'
    });
    expect(config.openclawDeliverReply).toBe(true);
    expect(config.openclawReplyChannel).toBe('telegram');
    expect(config.openclawReplyTo).toBe('telegram:1234');
    expect(config.openclawMessageStyle).toBe('compact');
    expect(config.siriMessagePrefix).toBe('Sent via Apple Watch voice message:');
  });
});
