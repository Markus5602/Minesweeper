<script lang="ts">
  import Scoreboard from './Scoreboard.svelte';
  import { supabase } from './supabaseClient';

  type Cell = {
    row: number;
    col: number;
    mine: boolean;
    revealed: boolean;
    flagged: boolean;
    neighborMines: number;
  };

  const ROWS = 20;
  const COLS = 24;
  const MINE_COUNT = 99;

  let board: Cell[][] = $state([]);
  let gameOver = $state(false);
  let gameWon = $state(false);
  let firstClick = $state(true);
  let timer = $state(0);
  let flagsCount = $state(0);
  let revealedCount = $state(0);
  let timerInterval: ReturnType<typeof setInterval> | null = null;

  // Score submission state
  let playerName = $state('');
  let scoreSaved = $state(false);
  let scoreSaving = $state(false);
  let saveError = $state(false);

  // Refresh signal for the scoreboard
  let refreshSignal = $state(0);

  const { onscoresaved } = $props();

  const resetEmoji = $derived(gameOver ? '😵' : gameWon ? '😎' : '😊');
  const remainingMines = $derived(MINE_COUNT - flagsCount);

  function initGame() {
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = null;
    board = [];
    gameOver = false;
    gameWon = false;
    firstClick = true;
    timer = 0;
    flagsCount = 0;
    revealedCount = 0;
    playerName = '';
    scoreSaved = false;
    scoreSaving = false;
    saveError = false;
  }

  function startTimer() {
    timerInterval = setInterval(() => {
      if (timer < 999) {
        timer++;
      }
    }, 1000);
  }

  function placeMines(firstR: number, firstC: number) {
    let placed = 0;
    while (placed < MINE_COUNT) {
      const r = Math.floor(Math.random() * ROWS);
      const c = Math.floor(Math.random() * COLS);
      const isNearStart = Math.abs(r - firstR) <= 1 && Math.abs(c - firstC) <= 1;
      if (!board[r][c].mine && !isNearStart) {
        board[r][c].mine = true;
        placed++;
      }
    }
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (!board[r][c].mine) {
          board[r][c].neighborMines = countNeighborMines(r, c);
        }
      }
    }
  }

  function countNeighborMines(r: number, c: number): number {
    let count = 0;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        const nr = r + dr;
        const nc = c + dc;
        if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS) {
          if (board[nr][nc].mine) count++;
        }
      }
    }
    return count;
  }

  function handleCellClick(r: number, c: number) {
    if (gameOver || gameWon) return;
    const cell = board[r][c];
    if (cell.flagged || cell.revealed) return;

    if (firstClick) {
      firstClick = false;
      placeMines(r, c);
      startTimer();
    }

    if (cell.mine) {
      revealAllMines();
      cell.revealed = true;
      gameOver = true;
      if (timerInterval) clearInterval(timerInterval);
      return;
    }

    revealCell(r, c);
    checkWinCondition();
  }

  function revealCell(r: number, c: number) {
    const cell = board[r][c];
    if (cell.revealed || cell.flagged) return;

    cell.revealed = true;
    revealedCount++;

    if (cell.neighborMines === 0) {
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
          const nr = r + dr;
          const nc = c + dc;
          if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS) {
            if (!board[nr][nc].revealed) {
              revealCell(nr, nc);
            }
          }
        }
      }
    }
  }

  function handleCellRightClick(e: Event, r: number, c: number) {
    e.preventDefault();
    if (gameOver || gameWon || firstClick) return;
    const cell = board[r][c];
    if (cell.revealed) return;

    if (!cell.flagged) {
      cell.flagged = true;
      flagsCount++;
    } else {
      cell.flagged = false;
      flagsCount--;
    }
  }

  function revealAllMines() {
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (board[r][c].mine) {
          board[r][c].revealed = true;
        }
      }
    }
  }

  function checkWinCondition() {
    if (revealedCount === ROWS * COLS - MINE_COUNT) {
      gameWon = true;
      if (timerInterval) clearInterval(timerInterval);
      for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
          if (board[r][c].mine && !board[r][c].flagged) {
            board[r][c].flagged = true;
            flagsCount++;
          }
        }
      }
    }
  }

  async function submitScore() {
    const name = playerName.trim();
    if (!name || scoreSaving || scoreSaved) return;
    scoreSaving = true;
    saveError = false;
    const { error } = await supabase
      .from('scores')
      .insert({ player_name: name, time_seconds: timer });
    scoreSaving = false;
    if (error) {
      saveError = true;
    } else {
      scoreSaved = true;
      refreshSignal++;
      onscoresaved?.();
    }
  }

  function cellLabel(cell: Cell): string {
    if (!cell.revealed && cell.flagged) return '🚩';
    if (!cell.revealed) return '';
    if (cell.mine) return '💣';
    if (cell.neighborMines > 0) return String(cell.neighborMines);
    return '';
  }

  function cellClass(cell: Cell): string {
    let cls = 'cell';
    if (cell.revealed) cls += ' revealed';
    if (cell.revealed && cell.mine) cls += ' mine';
    return cls;
  }

  initGame();
</script>

<div class="minesweeper-container" class:game-won={gameWon} class:game-lost={gameOver}>
  <header class="game-header">
    <div class="counter">{String(remainingMines).padStart(3, '0')}</div>
    <button class="reset-btn" onclick={initGame}>{resetEmoji}</button>
    <div class="counter">{String(timer).padStart(3, '0')}</div>
  </header>

  <div class="board-wrapper">
    <div class="board" style="grid-template-columns: repeat({COLS}, 1fr); grid-template-rows: repeat({ROWS}, 1fr)" aria-label="Spielfeld" class:shake={gameOver}>
      {#each board as row}
        {#each row as cell}
          <div
            class={cellClass(cell)}
            data-value={cell.revealed && cell.neighborMines > 0 ? cell.neighborMines : ''}
            role="button"
            tabindex="0"
            onclick={() => handleCellClick(cell.row, cell.col)}
            oncontextmenu={(e) => handleCellRightClick(e, cell.row, cell.col)}
            onkeydown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                handleCellClick(cell.row, cell.col);
              } else if (e.key === 'f' || e.key === 'F') {
                e.preventDefault();
                handleCellRightClick(e, cell.row, cell.col);
              }
            }}
          >
            {cellLabel(cell)}
          </div>
        {/each}
      {/each}
    </div>

    {#if gameWon}
      <div class="overlay overlay-win">
        <div class="overlay-content win-content">
          <div class="overlay-icon">😎</div>
          <div class="overlay-title">Gewonnen!</div>
          <div class="overlay-subtitle">Zeit: {timer}s</div>

          {#if !scoreSaved}
            <div class="score-form">
              <input
                class="score-input"
                type="text"
                placeholder="Dein Name"
                maxlength="20"
                bind:value={playerName}
                onkeydown={(e) => { if (e.key === 'Enter') submitScore(); }}
              />
              <button class="overlay-btn" onclick={submitScore} disabled={scoreSaving || !playerName.trim()}>
                {scoreSaving ? 'Speichert…' : 'In Bestenliste eintragen'}
              </button>
            </div>
            {#if saveError}
              <div class="score-error">Fehler beim Speichern. Nochmal versuchen.</div>
            {/if}
          {:else}
            <div class="score-saved">Zeit gespeichert!</div>
            <button class="overlay-btn" onclick={initGame}>Nochmal spielen</button>
          {/if}
        </div>
      </div>
    {:else if gameOver}
      <div class="overlay overlay-lose">
        <div class="overlay-content lose-content">
          <div class="overlay-icon">💥</div>
          <div class="overlay-title">Verloren!</div>
          <button class="overlay-btn" onclick={initGame}>Nochmal versuchen</button>
        </div>
      </div>
    {/if}
  </div>
</div>
