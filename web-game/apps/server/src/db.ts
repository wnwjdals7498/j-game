import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

export function openDb(path: string): DatabaseSync {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, provider TEXT NOT NULL, provider_user_id TEXT NOT NULL, display_name TEXT NOT NULL, is_qa INTEGER NOT NULL, created_at TEXT NOT NULL, UNIQUE (provider, provider_user_id));
    CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), expires_at TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, game_id TEXT NOT NULL, mode TEXT NOT NULL, room_code TEXT UNIQUE, player0_user_id INTEGER, player1_user_id INTEGER, bot_level TEXT, bot_seed INTEGER, status TEXT NOT NULL, end_reason TEXT, resigned_by INTEGER, created_at TEXT NOT NULL, ended_at TEXT);
    CREATE TABLE IF NOT EXISTS moves (game_id INTEGER NOT NULL REFERENCES games(id), seq INTEGER NOT NULL, player INTEGER NOT NULL, move TEXT NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY (game_id, seq));
  `);
  return db;
}
