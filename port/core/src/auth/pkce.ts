import { randomBytes, createHash } from 'node:crypto';

export interface PkcePair {
  verifier: string;
  challenge: string;
}

function base64url(data: Buffer): string {
  return data.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

export function createPkcePair(): PkcePair {
  const verifier = base64url(randomBytes(32));
  const challenge = base64url(
    Buffer.from(createHash('sha256').update(verifier).digest()),
  );
  return { verifier, challenge };
}

export function generateState(): string {
  return base64url(randomBytes(32));
}
