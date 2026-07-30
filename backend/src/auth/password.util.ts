import { randomInt } from 'crypto';

// Ambiguous glyphs (I/l/1, O/0) are excluded so a temp password read aloud or
// copied from paper isn't misread.
const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWER = 'abcdefghijkmnpqrstuvwxyz';
const DIGIT = '23456789';
const ALL = UPPER + LOWER + DIGIT;

/**
 * A random, human-transcribable temporary password. Guaranteed to satisfy the
 * change-password policy (upper + lower + digit, length >= 8) so the account it
 * is set on can always be handed over and then changed by the user.
 */
export function generateTempPassword(length = 10): string {
  const pick = (set: string) => set[randomInt(set.length)];
  const chars = [pick(UPPER), pick(LOWER), pick(DIGIT), pick(DIGIT)];
  while (chars.length < length) chars.push(pick(ALL));
  // Fisher–Yates shuffle so the guaranteed classes aren't always in fixed slots.
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}
