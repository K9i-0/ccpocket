/**
 * Firebase Anonymous Auth client for Bridge Server.
 *
 * Uses the Firebase Auth REST API directly instead of the client SDK
 * to avoid Node.js compatibility issues with the browser-oriented SDK.
 *
 * Each Bridge instance signs in anonymously and obtains:
 * - A unique UID (used as bridgeId)
 * - An ID token (used as Bearer token for Cloud Functions)
 *
 * Note: Each restart creates a new anonymous UID. This is acceptable
 * because the Flutter app re-registers its FCM token on every WebSocket reconnect.
 */

const FIREBASE_API_KEY = "AIzaSyAptNnokWPqJIgv2Lr3I8ETN6bqZb5BGvc";
const SIGN_UP_URL = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_API_KEY}`;
const REFRESH_URL = `https://securetoken.googleapis.com/v1/token?key=${FIREBASE_API_KEY}`;

interface SignUpResponse {
  idToken: string;
  refreshToken: string;
  localId: string; // UID
  expiresIn: string; // seconds
}

interface RefreshResponse {
  id_token: string;
  refresh_token: string;
  expires_in: string;
  user_id: string;
}

export class FirebaseAuthClient {
  private _uid: string | null = null;
  private _idToken: string | null = null;
  private _refreshToken: string | null = null;
  private _expiresAt: number = 0;

  get uid(): string {
    if (!this._uid) throw new Error("Firebase auth not initialized");
    return this._uid;
  }

  /**
   * Sign in anonymously via Firebase Auth REST API.
   */
  async initialize(): Promise<void> {
    const res = await fetch(SIGN_UP_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ returnSecureToken: true }),
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Firebase anonymous sign-in failed (${res.status}): ${text}`);
    }

    const data = (await res.json()) as SignUpResponse;
    this._uid = data.localId;
    this._idToken = data.idToken;
    this._refreshToken = data.refreshToken;
    this._expiresAt = Date.now() + (parseInt(data.expiresIn, 10) || 3600) * 1000 - 60_000; // refresh 1min early

    console.log(`[firebase-auth] Signed in anonymously. UID: ${this._uid}`);
  }

  /**
   * Returns a fresh Firebase ID token.
   * Automatically refreshes if the token is expired or about to expire.
   */
  async getIdToken(): Promise<string> {
    if (!this._idToken || !this._refreshToken) {
      throw new Error("Firebase auth not initialized");
    }

    if (Date.now() >= this._expiresAt) {
      await this.refreshIdToken();
    }

    return this._idToken!;
  }

  private async refreshIdToken(): Promise<void> {
    const res = await fetch(REFRESH_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(this._refreshToken!)}`,
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`Firebase token refresh failed (${res.status}): ${text}`);
    }

    const data = (await res.json()) as RefreshResponse;
    this._idToken = data.id_token;
    this._refreshToken = data.refresh_token;
    this._expiresAt = Date.now() + (parseInt(data.expires_in, 10) || 3600) * 1000 - 60_000;

    console.log("[firebase-auth] ID token refreshed");
  }
}
