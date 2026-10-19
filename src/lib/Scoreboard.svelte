<script lang="ts">
  import { supabase, type Score } from './supabaseClient';

  let { refreshSignal = 0 } = $props();

  let scores: Score[] = $state([]);
  let loading = $state(true);
  let error = $state(false);

  async function loadScores() {
    loading = true;
    error = false;
    const { data, error: err } = await supabase
      .from('scores')
      .select('id, player_name, time_seconds, created_at')
      .order('time_seconds', { ascending: true })
      .limit(100);
    if (err) {
      error = true;
    } else {
      scores = data as Score[];
    }
    loading = false;
  }

  // Load on mount
  loadScores();

  // Reload when the refresh signal changes (e.g. after a new score is saved)
  $effect(() => {
    if (refreshSignal > 0) {
      loadScores();
    }
  });

  function formatDate(iso: string): string {
    const d = new Date(iso);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  }
</script>

<div class="scoreboard">
  <h2 class="scoreboard-title">Bestenliste · Top 100</h2>

  {#if loading}
    <div class="scoreboard-loading">Lade Zeiten…</div>
  {:else if error}
    <div class="scoreboard-error">Fehler beim Laden der Bestenliste.</div>
  {:else if scores.length === 0}
    <div class="scoreboard-empty">Noch keine Einträge. Sei der Erste!</div>
  {:else}
    <div class="scoreboard-list-wrapper">
      <table class="scoreboard-table">
        <thead>
          <tr>
            <th class="rank-col">#</th>
            <th>Name</th>
            <th class="time-col">Zeit</th>
            <th class="date-col">Datum</th>
          </tr>
        </thead>
        <tbody>
          {#each scores as score, i}
            <tr class:rank-1={i === 0} class:rank-2={i === 1} class:rank-3={i === 2}>
              <td class="rank-col">{i + 1}</td>
              <td class="name-cell">{score.player_name}</td>
              <td class="time-col">{score.time_seconds}s</td>
              <td class="date-col">{formatDate(score.created_at)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}

  <button class="scoreboard-refresh" onclick={loadScores}>Aktualisieren</button>
</div>

<style>
  .scoreboard {
    background-color: #c0c0c0;
    border: 4px outset #ffffff;
    padding: 16px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
    border-radius: 2px;
    width: 320px;
    max-height: 600px;
    display: flex;
    flex-direction: column;
    align-self: flex-start;
  }

  .scoreboard-title {
    font-size: 20px;
    font-weight: 700;
    margin: 0 0 12px 0;
    text-align: center;
    color: #1a1a25;
  }

  .scoreboard-loading,
  .scoreboard-error,
  .scoreboard-empty {
    text-align: center;
    padding: 24px 0;
    color: #555;
    font-size: 14px;
  }

  .scoreboard-list-wrapper {
    flex: 1;
    overflow-y: auto;
    border: 3px inset #ffffff;
    background-color: #d8d8d8;
    margin-bottom: 12px;
    max-height: 480px;
  }

  .scoreboard-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    color: #1a1a25;
  }

  .scoreboard-table thead th {
    position: sticky;
    top: 0;
    background-color: #808080;
    color: #fff;
    font-weight: 700;
    padding: 6px 8px;
    text-align: left;
    z-index: 1;
  }

  .scoreboard-table tbody tr {
    border-bottom: 1px solid #b0b0b0;
  }

  .scoreboard-table tbody tr:hover {
    background-color: #c8c8d0;
  }

  .scoreboard-table td {
    padding: 5px 8px;
  }

  .rank-col {
    width: 32px;
    text-align: center;
    font-weight: 700;
  }

  .time-col {
    width: 50px;
    text-align: right;
    font-family: 'Courier New', Courier, monospace;
    font-weight: 700;
  }

  .date-col {
    width: 56px;
    text-align: right;
    font-size: 11px;
    opacity: 0.7;
  }

  .name-cell {
    font-weight: 500;
  }

  tr.rank-1 .rank-col { color: #c0a000; }
  tr.rank-2 .rank-col { color: #888; }
  tr.rank-3 .rank-col { color: #b06820; }

  tr.rank-1 { background-color: rgba(192, 160, 0, 0.08); }
  tr.rank-2 { background-color: rgba(136, 136, 136, 0.08); }
  tr.rank-3 { background-color: rgba(176, 104, 32, 0.08); }

  .scoreboard-refresh {
    padding: 6px 16px;
    font-size: 13px;
    font-weight: 600;
    border: 2px outset #ffffff;
    background-color: #c0c0c0;
    cursor: pointer;
    border-radius: 2px;
    align-self: center;
    transition: filter 0.1s;
  }

  .scoreboard-refresh:hover {
    filter: brightness(1.05);
  }

  .scoreboard-refresh:active {
    border: 2px inset #ffffff;
  }

  @media (max-width: 1100px) {
    .scoreboard {
      width: 100%;
      max-height: 400px;
    }
  }
</style>
