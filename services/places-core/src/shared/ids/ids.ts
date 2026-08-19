import { createHash } from 'crypto';
import { v7 as uuidv7 } from 'uuid';

export function newId(): string {
  return uuidv7();
}

export function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}
