import { randomBytes } from 'node:crypto';
import type { DatabaseSync } from 'node:sqlite';
import type { UserView } from '@jgame/protocol';

type UserRecord = { id: number; name: string; isQa: number; provider: string };
function view(row: UserRecord | undefined): UserView | undefined { return row && { ...row, isQa: Boolean(row.isQa) }; }
export function upsertUser(db: DatabaseSync, p: { provider: string; providerUserId: string; displayName: string; isQa: boolean }): UserView {
  const row = db.prepare(`INSERT INTO users (provider, provider_user_id, display_name, is_qa, created_at) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT (provider, provider_user_id) DO UPDATE SET display_name = excluded.display_name, is_qa = excluded.is_qa
    RETURNING id, display_name AS name, is_qa AS isQa, provider`).get(p.provider, p.providerUserId, p.displayName, Number(p.isQa), new Date().toISOString()) as UserRecord;
  return view(row)!;
}
export function getUser(db: DatabaseSync, id: number): UserView | undefined {
  return view(db.prepare('SELECT id, display_name AS name, is_qa AS isQa, provider FROM users WHERE id = ?').get(id) as UserRecord | undefined);
}
export function createSession(db: DatabaseSync, userId: number, ttlMs: number, now: Date = new Date()): string {
  const sid = randomBytes(32).toString('base64url');
  db.prepare('INSERT INTO sessions (id, user_id, expires_at) VALUES (?, ?, ?)').run(sid, userId, new Date(now.getTime() + ttlMs).toISOString());
  return sid;
}
export function getSessionUser(db: DatabaseSync, sid: string, now: Date): UserView | undefined {
  return view(db.prepare('SELECT users.id, users.display_name AS name, users.is_qa AS isQa, users.provider FROM sessions JOIN users ON users.id = sessions.user_id WHERE sessions.id = ? AND sessions.expires_at > ?').get(sid, now.toISOString()) as UserRecord | undefined);
}
export function deleteSession(db: DatabaseSync, sid: string): void { db.prepare('DELETE FROM sessions WHERE id = ?').run(sid); }
