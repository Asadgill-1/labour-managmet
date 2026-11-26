"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";
import { gate, signOut, touch, type Gate } from "@/lib/session";
import { menu } from "@/lib/words";

/** The cover bar and the gate: nothing below it renders until the session has the password and the TOTP code. */
export function Shell({ children }: { children: ReactNode }) {
  const router = useRouter();
  const path = usePathname();
  const [state, setState] = useState<{ gate: Gate | null; email: string | null }>({ gate: null, email: null });

  useEffect(() => {
    let live = true;
    const check = () => gate().then((g) => {
      if (!live) return;
      setState(g);
      if (g.gate === "out") router.replace("/login/");
      if (g.gate === "code") router.replace("/login/?step=code");
    });
    check();
    const every = setInterval(check, 60_000);
    const seen = () => touch();
    window.addEventListener("pointerdown", seen);
    window.addEventListener("keydown", seen);
    return () => {
      live = false;
      clearInterval(every);
      window.removeEventListener("pointerdown", seen);
      window.removeEventListener("keydown", seen);
    };
  }, [router]);

  return (
    <>
      <header className="bar">
        <div className="cap">
          <Link className="mark" href="/">Labour app, malik</Link>
          <nav className="nav" aria-label="Dashboard">
            {menu.map((m) => (
              <Link key={m.href} href={m.href} aria-current={(m.href === "/" ? path === "/" : path.startsWith(m.href.slice(0, -1))) || (m.href === "/accounts/" && path.startsWith("/account/")) ? "page" : undefined}>
                {m.label}
              </Link>
            ))}
          </nav>
          {state.email ? <span className="who">{state.email}, MFA se andar</span> : null}
          {state.gate === "in" ? (
            <button type="button" className="quiet" onClick={() => signOut().then(() => router.replace("/login/"))}>Sign out</button>
          ) : null}
        </div>
      </header>
      {state.gate === "in" ? children : state.gate === "missing" ? <Missing /> : <div className="cap page" aria-busy="true"><span className="skel w60" /><span className="skel w40" /></div>}
    </>
  );
}

function Missing() {
  return (
    <main className="cap page">
      <div className="notice">
        <b>Cloud ka pata nahin likha.</b> `apps/admin/.env.local` mein live project ka URL aur public (anon) key likhein, phir site dobara chalayein. Secret key kabhi nahin (docs/RUNBOOK.md).
      </div>
    </main>
  );
}
