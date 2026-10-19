/*
# Create scores table for Minesweeper scoreboard (single-tenant, no auth)

1. New Tables
- `scores`
  - `id` (uuid, primary key)
  - `player_name` (text, not null) — the name the player enters when they win
  - `time_seconds` (integer, not null) — how long it took to solve the board
  - `created_at` (timestamptz, default now())

2. Indexes
- Index on `time_seconds` ascending so the "top 100 fastest" query is fast.
- Index on `created_at` descending for the query that keeps only the latest entries.

3. Security
- Enable RLS on `scores`.
- This is a no-auth app (no sign-in screen). All policies use `TO anon, authenticated`
  so the anon-key frontend can read and insert scores.
- SELECT is open to everyone (the scoreboard is public).
- INSERT is open to everyone (anyone can submit a score).
- No UPDATE or DELETE policies — scores are immutable once submitted.

4. Notes
- The scoreboard displays the top 100 fastest solving times ordered by `time_seconds` ascending.
- We keep at most 500 rows to prevent unbounded growth; a trigger trims older entries.
*/

CREATE TABLE IF NOT EXISTS scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_name text NOT NULL CHECK (length(trim(player_name)) > 0 AND length(player_name) <= 20),
  time_seconds integer NOT NULL CHECK (time_seconds > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scores_time_asc ON scores (time_seconds ASC);
CREATE INDEX IF NOT EXISTS idx_scores_created_desc ON scores (created_at DESC);

ALTER TABLE scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_scores" ON scores;
CREATE POLICY "anon_select_scores"
  ON scores FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "anon_insert_scores" ON scores;
CREATE POLICY "anon_insert_scores"
  ON scores FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Trim the table to the latest 500 rows after each insert
CREATE OR REPLACE FUNCTION trim_scores()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM scores
  WHERE id NOT IN (
    SELECT id FROM scores ORDER BY created_at DESC LIMIT 500
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trim_scores_trigger ON scores;
CREATE TRIGGER trim_scores_trigger
  AFTER INSERT ON scores
  FOR EACH ROW EXECUTE FUNCTION trim_scores();
