export function getHomeDir(): string {
  const home = process.env['HOME'];
  if (!home) throw new Error('HOME environment variable is not set');
  return home;
}

export const ANTHROPIC_API_BASE_URL =
  process.env['BATTERY_API_BASE_URL'] ?? 'https://api.anthropic.com';
