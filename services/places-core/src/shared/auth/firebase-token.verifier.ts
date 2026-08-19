import { Inject, Injectable } from '@nestjs/common';
import * as admin from 'firebase-admin';
import { createPublicKey, createVerify } from 'crypto';
import { APP_CONFIG } from '../config/app-config';
import { AppEnv } from '../config/env';
import { AppError } from '../errors/app-error';
import { ErrorCodes } from '../errors/error-codes';
import { AuthUser, PlacesClaim } from './auth-user';
import { TokenVerifierPort } from './token-verifier.port';

const CLAIMS: PlacesClaim[] = [
  'placesProvider',
  'placesAdmin',
  'placesFinance',
  'placesSupport',
  'placesInternalOperator',
];

type FirebaseCertCache = {
  fetchedAt: number;
  byKid: Map<string, string>;
};

/**
 * Verifies real Firebase ID tokens.
 * Prefers Admin SDK when ADC/credentials exist; otherwise verifies via Google's
 * public x509 certs (still real Firebase Auth — never Stub).
 */
@Injectable()
export class FirebaseTokenVerifier implements TokenVerifierPort {
  private readonly projectId: string;
  private adminReady = false;
  private certCache: FirebaseCertCache | null = null;

  constructor(@Inject(APP_CONFIG) env: AppEnv) {
    this.projectId = env.firebaseProjectId;
    if (!admin.apps.length) {
      try {
        admin.initializeApp({ projectId: env.firebaseProjectId });
        this.adminReady = true;
      } catch {
        this.adminReady = false;
      }
    } else {
      this.adminReady = true;
    }
  }

  async verify(token: string): Promise<AuthUser> {
    if (this.adminReady) {
      try {
        const decoded = await admin.auth().verifyIdToken(token);
        return this.toAuthUser(decoded as Record<string, unknown>);
      } catch (err) {
        // Fall through to JWKS path when ADC is missing locally.
        const msg = err instanceof Error ? err.message : String(err);
        if (!/credential|Could not load|Unable to detect/i.test(msg)) {
          if (err instanceof AppError) throw err;
          throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid Firebase ID token');
        }
      }
    }
    return this.verifyWithGoogleCerts(token);
  }

  private toAuthUser(decoded: Record<string, unknown>): AuthUser {
    const aud = decoded.aud;
    if (typeof aud === 'string' && aud !== this.projectId) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Token audience mismatch');
    }
    const exp = Number(decoded.exp ?? 0);
    if (exp * 1000 < Date.now()) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Token expired');
    }
    const uid = String(decoded.uid ?? decoded.sub ?? '');
    if (!uid) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Token missing uid');
    }
    const claims: AuthUser['claims'] = {};
    for (const c of CLAIMS) {
      if (decoded[c] === true) {
        claims[c] = true;
      }
    }
    return { uid, claims };
  }

  private async verifyWithGoogleCerts(token: string): Promise<AuthUser> {
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid Firebase ID token');
    }
    const [hB64, pB64, sB64] = parts;
    let header: { alg?: string; kid?: string };
    let payload: Record<string, unknown>;
    try {
      header = JSON.parse(Buffer.from(hB64, 'base64url').toString('utf8'));
      payload = JSON.parse(Buffer.from(pB64, 'base64url').toString('utf8'));
    } catch {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid Firebase ID token');
    }
    if (header.alg !== 'RS256' || !header.kid) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid Firebase ID token');
    }
    const certPem = await this.certForKid(header.kid);
    const verifier = createVerify('RSA-SHA256');
    verifier.update(`${hB64}.${pB64}`);
    verifier.end();
    const ok = verifier.verify(
      createPublicKey(certPem),
      Buffer.from(sB64, 'base64url'),
    );
    if (!ok) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid Firebase ID token');
    }
    const iss = `https://securetoken.google.com/${this.projectId}`;
    if (payload.iss !== iss) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Token issuer mismatch');
    }
    return this.toAuthUser(payload);
  }

  private async certForKid(kid: string): Promise<string> {
    const now = Date.now();
    if (!this.certCache || now - this.certCache.fetchedAt > 60 * 60 * 1000) {
      const res = await fetch(
        'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
      );
      if (!res.ok) {
        throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Firebase cert fetch failed');
      }
      const json = (await res.json()) as Record<string, string>;
      this.certCache = {
        fetchedAt: now,
        byKid: new Map(Object.entries(json)),
      };
    }
    const pem = this.certCache.byKid.get(kid);
    if (!pem) {
      // Force refresh once for rotated kids.
      this.certCache = null;
      const res = await fetch(
        'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
      );
      if (!res.ok) {
        throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Firebase cert fetch failed');
      }
      const json = (await res.json()) as Record<string, string>;
      this.certCache = { fetchedAt: Date.now(), byKid: new Map(Object.entries(json)) };
      const again = this.certCache.byKid.get(kid);
      if (!again) {
        throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Unknown Firebase token kid');
      }
      return again;
    }
    return pem;
  }
}
