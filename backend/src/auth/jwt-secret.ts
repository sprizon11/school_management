/**
 * The JWT secret signs both user sessions and platform-owner (dev portal)
 * tokens. Falling back to a hardcoded default would let anyone forge either,
 * so a missing secret is a startup failure rather than a silent default.
 */
export function requireJwtSecret(): string {
  const secret = process.env.JWT_SECRET?.trim();

  if (!secret) {
    throw new Error(
      'JWT_SECRET is not set. Refusing to start — set it in backend/.env ' +
        '(local) or the Cloud Run environment (deployed).',
    );
  }

  return secret;
}
