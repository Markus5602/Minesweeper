<script lang="ts">
  type Cell = {
    row: number;
    col: number;
    mine: boolean;
    revealed: boolean;
    flagged: boolean;
    neighborMines: number;
  };

  type GameState = {
    board: Cell[][];
    gameOver: boolean;
    gameWon: boolean;
    firstClick: boolean;
    timer: number;
    flagsCount: number;
    revealedCount: number;
  };

  const ROWS = 20;
  const COLS = 24;
  const MINE_COUNT = 99;
  const STORAGE_KEY = 'minesweeper-state';

  let board: Cell[][] = $state([]);
  let gameOver = $state(false);
  let gameWon = $state(false);
  let firstClick = $state(true);
  let timer = $state(0);
  let flagsCount = $state(0);
  let revealedCount = $state(0);
  let timerInterval: ReturnType<typeof setInterval> | null = null;

  const resetEmoji = $derived(gameOver ? '😵' : gameWon ? '😎' : '😊');
  const remainingMines = $derived(MINE_COUNT - flagsCount);

  function buildEmptyBoard(): Cell[][] {
    const b: Cell[][] = [];
    for (let r = 0; r < ROWS; r++) {
      const row: Cell[] = [];
      for (let c = 0; c < COLS; c++) {
        row.push({
          row: r,
          col: c,
          mine: false,
          revealed: false,
          flagged: false,
          neighborMines: 0,
        });
      }
      b.push(row);
    }
    return b;
  }

  function initGame() {
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = null;
    board = buildEmptyBoard();
    gameOver = false;
    gameWon = false;
    firstClick = true;
    timer = 0;
    flagsCount = 0;
    revealedCount = 0;
    saveState();
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
      saveState();
      return;
    }

    revealCell(r, c);
    checkWinCondition();
    saveState();
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
    saveState();
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

  function saveState() {
    const state: GameState = {
      board,
      gameOver,
      gameWon,
      firstClick,
      timer,
      flagsCount,
      revealedCount,
    };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {
      // ignore quota / serialization errors
    }
  }

  function loadState(): boolean {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return false;
      const state = JSON.parse(raw) as GameState;
      if (
        !state.board ||
        state.board.length !== ROWS ||
        state.board[0].length !== COLS
      ) {
        return false;
      }
      board = state.board;
      gameOver = state.gameOver;
      gameWon = state.gameWon;
      firstClick = state.firstClick;
      timer = state.timer;
      flagsCount = state.flagsCount;
      revealedCount = state.revealedCount;
      // Resume the timer only for an in-progress game
      if (!firstClick && !gameOver && !gameWon) {
        startTimer();
      }
      return true;
    } catch {
      return false;
    }
  }

  // On mount: restore a saved game, otherwise start fresh
  if (!loadState()) {
    initGame();
  }
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
          <button class="overlay-btn" onclick={initGame}>Nochmal spielen</button>
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
