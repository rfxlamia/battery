import { OAUTH_AUTHORIZE_URL, OAUTH_CLIENT_ID, OAUTH_SCOPES } from '../config/env.js';

interface AuthorizeUrlParams {
  redirectUri: string;
  state: string;
  codeChallenge: string;
}

export function buildAuthorizeUrl(params: AuthorizeUrlParams): string {
  const url = new URL(OAUTH_AUTHORIZE_URL);
  url.searchParams.set('client_id', OAUTH_CLIENT_ID);
  url.searchParams.set('redirect_uri', params.redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('scope', OAUTH_SCOPES);
  url.searchParams.set('code_challenge', params.codeChallenge);
  url.searchParams.set('code_challenge_method', 'S256');
  url.searchParams.set('state', params.state);
  return url.toString();
}
