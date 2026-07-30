import { createHash, randomBytes } from 'crypto';

/** A high-entropy opaque refresh token (URL-safe). Never a JWT. */
export function generateRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

/**
 * Refresh tokens are stored only as a SHA-256 hash, so a database leak can't be
 * replayed. SHA-256 (not bcrypt) is right here: the input is already
 * high-entropy, and refresh/rotate must be fast and lookup-by-hash.
 */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
