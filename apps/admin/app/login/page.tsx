"use client";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState, type FormEvent } from "react";
import { cloud } from "@/lib/cloud";
import { checkCode, gate, signOut, totpFactor } from "@/lib/session";

type Step = "password" | "enrol" | "code";

export default function LoginPage() {
  return <Suspense><Login /></Suspense>;
}

// Password, then the TOTP code; the first sign-in shows a QR code to enrol the authenticator app. There is no
// sign-up: an admin is added only in the SQL editor (RUNBOOK), and every admin_ function refuses anyone else.
function Login() {
  const router = useRouter();
  const params = useSearchParams();
  const [step, setStep] = useState<Step>(params.get("step") === "code" ? "code" : "password");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [enrol, setEnrol] = useState<{ id: string; qr: string; secret: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    gate().then(async (g) => {
      if (g.gate === "in") router.replace("/");
      else if (g.gate === "code") await afterPassword();
      else if (g.gate === "missing") setError("Cloud ka pata nahin likha: apps/admin/.env.local dekhein (RUNBOOK).");
    });
  }, []);

  async function afterPassword() {
    const c = cloud()!;
    if (await totpFactor()) return setStep("code");
    // A factor left half made by an earlier try is removed first, so enrolling again works.
    const { data: factors } = await c.auth.mfa.listFactors();
    for (const f of factors?.all.filter((x) => x.status !== "verified") ?? []) await c.auth.mfa.unenroll({ factorId: f.id });
    const { data, error } = await c.auth.mfa.enroll({ factorType: "totp", friendlyName: "Dashboard" });
    if (error || !data) return setError("MFA shuru nahin hua. Supabase mein TOTP on hai? (RUNBOOK)");
    setEnrol({ id: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
    setStep("enrol");
  }

  async function signIn(e: FormEvent) {
    e.preventDefault();
    const c = cloud();
    if (!c) return;
    setBusy(true);
    setError(null);
    const { error } = await c.auth.signInWithPassword({ email: email.trim(), password });
    if (error) {
      setBusy(false);
      return setError("Email ya password ghalat hai.");
    }
    localStorage.setItem("labour-admin-active", String(Date.now()));
    await afterPassword();
    setBusy(false);
  }

  async function verify(e: FormEvent) {
    e.preventDefault();
    const c = cloud();
    if (!c) return;
    setBusy(true);
    setError(null);
    let wrong: string | null;
    if (step === "enrol" && enrol) {
      const { error } = await c.auth.mfa.challengeAndVerify({ factorId: enrol.id, code: code.trim() });
      wrong = error ? "Code ghalat hai. Authenticator app mein naya code dekhein." : null;
    } else {
      wrong = await checkCode(code.trim());
    }
    setBusy(false);
    if (wrong) return setError(wrong);
    router.replace("/");
  }

  return (
    <main className="signin">
      <div className="sheet">
        <div className="sheet-head">
          <h1>Malik ka dashboard</h1>
          <p>Sirf platform ke malik ke liye. Har kaam audit log mein jata hai.</p>
        </div>
        <div className="sheet-body">
          {step === "password" ? (
            <form onSubmit={signIn}>
              <label>Email<input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
              <label>Password<input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></label>
              {error ? <p className="field-warn" role="alert">{error}</p> : null}
              <div className="actions"><button type="submit" className="primary" disabled={busy} aria-busy={busy}>{busy ? "Ho raha hai" : "Aage"}</button></div>
            </form>
          ) : (
            <form onSubmit={verify}>
              {step === "enrol" && enrol ? (
                <div>
                  <p>Pehli dafa: authenticator app (Google Authenticator, Microsoft Authenticator ya 1Password) mein ye QR code scan karein, phir app ka 6 hindse ka code likhein.</p>
                  <div className="qr">
                    <img src={enrol.qr} alt="MFA ka QR code" />
                  </div>
                  <p className="field-note">Scan na ho to ye chabi likhein: <code className="secret">{enrol.secret}</code></p>
                </div>
              ) : (
                <p>Authenticator app ka 6 hindse ka code likhein.</p>
              )}
              <label>Code<input inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} onChange={(e) => setCode(e.target.value)} required autoFocus /></label>
              {error ? <p className="field-warn" role="alert">{error}</p> : null}
              <div className="actions">
                <button type="submit" className="primary" disabled={busy} aria-busy={busy}>{busy ? "Ho raha hai" : "Andar jayein"}</button>
                <button type="button" className="quiet" onClick={() => signOut().then(() => { setStep("password"); setCode(""); setEnrol(null); })}>Doosre email se</button>
              </div>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
