export default function Home() {
  return (
    <main>
      <h1>Wavelet</h1>
      <p>
        Share exactly the Apple Health categories you choose with the AI
        assistants you connect — and nothing else.
      </p>

      <h2>How it works</h2>
      <ul>
        <li>The iPhone app reads only the categories you switch on. Everything starts off.</li>
        <li>It totals each day on your device and syncs only those daily summaries.</li>
        <li>Assistants you connect — ChatGPT, Claude, and others — read those summaries over the Model Context Protocol.</li>
        <li>Switch a category off and it becomes unreadable immediately.</li>
      </ul>

      <h2>Why the toggle is real</h2>
      <p>
        A category you have not enabled is not merely hidden in the app. The
        server can only read through a database view that joins your consent
        settings, so a category that is off cannot be returned at all — not by a
        mistake, and not by a bug in the server.
      </p>

      <h2>What it never does</h2>
      <ul>
        <li>It never uploads raw Health records — only daily summaries.</li>
        <li>It never uses your health data for advertising, marketing or profiling.</li>
        <li>It never sells your data.</li>
        <li>It offers no diagnosis and no medical advice.</li>
      </ul>

      <h2>Open source</h2>
      <p>
        Every claim above is checkable:{" "}
        <a href="https://github.com/jx-grxf/HealthKit-MCP">github.com/jx-grxf/HealthKit-MCP</a>.
      </p>

      <p style={{ marginTop: "3rem" }}>
        <a href="/privacy">Privacy policy</a>
      </p>
    </main>
  );
}
