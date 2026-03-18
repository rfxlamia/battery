export function getHomeDir(): string {
  const home = process.env['HOME'];
  if (!home) throw new Error('HOME environment variable is not set');
  return home;
}

export const ANTHROPIC_API_BASE_URL =
  process.env['BATTERY_API_BASE_URL'] ?? 'https://api.anthropic.com';
export const ANTHROPIC_BETA_HEADER =
  process.env['BATTERY_ANTHROPIC_BETA_HEADER'] ?? 'oauth-2025-04-20';
export const BATTERY_USER_AGENT =
  process.env['BATTERY_USER_AGENT'] ?? 'Battery/0.2.4';
export const OAUTH_CLIENT_ID =
  process.env['BATTERY_OAUTH_CLIENT_ID'] ?? '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
export const OAUTH_SCOPES =
  process.env['BATTERY_OAUTH_SCOPES'] ?? 'user:profile user:inference';
export const OAUTH_TOKEN_URL =
  process.env['BATTERY_OAUTH_TOKEN_URL'] ?? 'https://platform.claude.com/v1/oauth/token';
