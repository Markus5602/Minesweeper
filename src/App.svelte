<script lang="ts">
  import Minesweeper from './lib/Minesweeper.svelte';
  import Scoreboard from './lib/Scoreboard.svelte';

  let scoreRefreshSignal = $state(0);

  function handleScoreSaved() {
    scoreRefreshSignal++;
  }
</script>

<main class="app">
  <h1>Minesweeper</h1>
  <div class="game-layout">
    <Minesweeper onscoresaved={handleScoreSaved} />
    <Scoreboard refreshSignal={scoreRefreshSignal} />
  </div>
</main>

<style>
  .game-layout {
    display: flex;
    gap: 24px;
    align-items: flex-start;
    flex-wrap: wrap;
    justify-content: center;
  }

  @media (max-width: 1100px) {
    .game-layout {
      flex-direction: column;
      align-items: center;
    }
  }
</style>
