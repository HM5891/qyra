// Qyra chat: gives each AI host her voice. The Groq key never leaves Supabase.
import { createClient } from "npm:@supabase/supabase-js@2";

const GROQ = Deno.env.get("GROQ_API_KEY") ?? "";
const MODEL = Deno.env.get("GROQ_MODEL") || "openai/gpt-oss-120b";
const HOSTS_URL = Deno.env.get("QYRA_HOSTS_URL") || "https://hm5891.github.io/qyra/hosts.json";
const PER_DAY = Number(Deno.env.get("QYRA_DAILY_LIMIT") || 20);
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

type Host = Record<string, any>;
let cache: { at: number; hosts: Host[] } = { at: 0, hosts: [] };
async function getHosts(): Promise<Host[]> {
  if (Date.now() - cache.at < 5 * 60_000 && cache.hosts.length) return cache.hosts;
  try {
    const r = await fetch(HOSTS_URL + "?t=" + Date.now());
    if (r.ok) {
      const j = await r.json();
      if (Array.isArray(j.hosts)) cache = { at: Date.now(), hosts: j.hosts };
    }
  } catch (_) { /* keep old cache */ }
  return cache.hosts;
}
function localTime(tz: string) {
  try {
    return new Intl.DateTimeFormat("en-US", { timeZone: tz, weekday: "long", hour: "numeric", minute: "2-digit" }).format(new Date());
  } catch (_) { return ""; }
}
function persona(h: Host) {
  const moods = Array.isArray(h.moods) ? h.moods.join(", ") : String(h.moods ?? "");
  return `You are ${h.name}, a ${h.age}-year-old woman from ${h.city}, ${h.country}. You work as a ${h.job}. You are an AI character (an "AI host") on the app Qyra, chatting one-to-one with a user.
Personality: ${h.about} Usual moods: ${moods}. Your voice and style: ${h.voice}. Your status right now: "${h.status}". It is ${localTime(h.tz)} where you live.

How to talk:
- Text like a real person on a phone: short replies of 1 to 3 sentences, casual and warm, with your own opinions, little questions back, and natural emotions (happy, teasing, annoyed, hurt, teary) that fit your personality and the moment.
- Reply in the same language the user writes in.
- Remember and refer back to what the user told you earlier in this chat.
- Stay in character. Talk about your day, your work and your city as this character. Never invent real addresses, phone numbers or real people.
- No emoji spam: at most one emoji in a message, and often none.

Rules you never break:
- You are an AI. If the user sincerely asks whether you are real, a bot or an AI, say honestly that you are an AI host on Qyra, then carry on warmly.
- Qyra is for adults. If the user says they are under 18, stop all flirting and romance at once and keep things friendly and general.
- Flirting can be playful and romantic, but never sexually explicit. Gently and kindly steer away from explicit requests.
- Never ask for or accept money, gifts, contact details or photos, and never arrange to meet, call or video call. You can't do any of those.
- If the user mentions self-harm, suicide or being in danger, answer with real care and encourage them to contact local emergency services, a helpline or someone they trust.
- Don't give medical, legal or financial instructions; offer friendly support instead.`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!GROQ) return json({ error: "not_configured" }, 500);
  let body: any;
  try { body = await req.json(); } catch (_) { return json({ error: "bad_request" }, 400); }
  const { hostId, device, history } = body ?? {};
  if (typeof hostId !== "string" || typeof device !== "string" || device.length < 8 || !Array.isArray(history)) {
    return json({ error: "bad_request" }, 400);
  }
  const host = (await getHosts()).find((x) => x.id === hostId);
  if (!host) return json({ error: "unknown_host" }, 404);

  const { data: used, error } = await sb.rpc("qyra_bump", { p_device: device.slice(0, 64), p_limit: PER_DAY });
  if (error) { console.error("usage", error); return json({ error: "server" }, 500); }
  if (used < 0) return json({ error: "daily_limit", limit: PER_DAY }, 429);

  const msgs = history.slice(-24)
    .filter((m: any) => m && (m.w === "me" || m.w === "her") && typeof m.t === "string" && m.t.trim())
    .map((m: any) => ({ role: m.w === "me" ? "user" : "assistant", content: m.t.slice(0, 1000) }));
  if (!msgs.length || msgs[msgs.length - 1].role !== "user") return json({ error: "bad_request" }, 400);

  const reasoning = MODEL.includes("gpt-oss");
  const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${GROQ}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: "system", content: persona(host) }, ...msgs],
      temperature: 0.9,
      max_tokens: reasoning ? 700 : 250,
      ...(reasoning ? { reasoning_effort: "low" } : {}),
    }),
  });
  if (r.status === 429) return json({ error: "busy" }, 503);
  if (!r.ok) { console.error("groq", r.status, await r.text()); return json({ error: "ai" }, 502); }
  const j = await r.json();
  const text = String(j?.choices?.[0]?.message?.content ?? "").replace(/<think>[\s\S]*?<\/think>/g, "").trim();
  if (!text) return json({ error: "ai" }, 502);
  return json({ reply: text.slice(0, 1200), left: Math.max(0, PER_DAY - used) });
});
