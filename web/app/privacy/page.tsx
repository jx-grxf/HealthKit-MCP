export const metadata = { title: "Wavelet — Privacy Policy" };

export default function Privacy() {
  return (
    <main>
      <h1>Privacy Policy</h1>

      <h2>Controller</h2>
      <p>Johannes Grof. Contact: contact@johannesgrof.me.</p>

      <h2>What is processed</h2>
      <p>
        Daily summaries of the Apple Health categories you explicitly switch on,
        each stored with the timestamp at which you consented to it. Also your
        account identifier from Sign in with Apple, and an audit record of every
        read performed by an AI assistant you connected.
      </p>
      <p>
        Individual Health measurements are never transmitted. Aggregation happens
        on your iPhone.
      </p>

      <h2>Legal basis</h2>
      <p>
        Health data is a special category of personal data under Article 9 GDPR.
        Processing rests solely on your explicit consent under Article 9(2)(a),
        given per category. There is no other legal basis, and withdrawing
        consent stops the processing.
      </p>

      <h2>Recipients</h2>
      <p>
        The AI assistants you personally connect — for example ChatGPT (OpenAI)
        or Claude (Anthropic) — receive the summaries for the categories you
        enabled, at the moment they query them on your behalf. No assistant is
        connected unless you complete an authorization step yourself.
      </p>
      <p>
        Infrastructure providers act as processors: Supabase (database and
        authentication, EU region) and Railway (application hosting).
      </p>

      <h2>Where it is stored</h2>
      <p>
        In the European Union (Frankfurt). Connections to the database are
        encrypted in transit and rejected if not.
      </p>

      <h2>Retention</h2>
      <p>
        Summaries are kept until you delete them or delete your account, which
        removes them permanently. Switching a category off stops further
        collection and makes existing entries unreadable to assistants.
      </p>

      <h2>Your rights</h2>
      <p>
        Access, rectification, erasure, restriction, portability, and withdrawal
        of consent at any time, under Articles 15–21 GDPR. You may also complain
        to a supervisory authority — in Austria, the Datenschutzbehörde.
      </p>

      <h2>No medical use</h2>
      <p>
        Wavelet is not a medical device. It offers no diagnosis, treatment or
        medical advice, and must not be used as a basis for medical decisions.
      </p>
    </main>
  );
}
