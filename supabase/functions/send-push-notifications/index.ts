import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

// Option A secrets
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!
let FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")!

// Normalisation \n
FIREBASE_PRIVATE_KEY = FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")

const MESSAGES = [
  "Comment te sens-tu en ce moment ? 🌿",
  "Prends un instant pour toi 💙",
  "Un petit check-in ? 😊",
  "Comment va ton humeur aujourd'hui ? ✨",
  "Et toi, comment ça va ? 🍃",
  "Besoin d'un moment pour toi ? 🌊",
  "Petit point sur tes émotions ? 💚",
]

serve(async () => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data: users, error } = await supabase.rpc("get_users_to_notify_push")
    if (error) throw error

    if (!users || users.length === 0) {
      return json({ message: "No users to notify" })
    }

    console.log(`🔔 Sending push to ${users.length} user(s)`)

    const accessToken = await getAccessTokenWebCrypto({
      clientEmail: FIREBASE_CLIENT_EMAIL,
      privateKeyPem: FIREBASE_PRIVATE_KEY,
    })

    const results = await Promise.all(users.map((u: any) => sendPush(u, accessToken)))
    const success = results.filter((r) => r.success).length

    return json({ message: `Sent ${success}/${users.length} notifications`, results })
  } catch (err: any) {
    console.error("❌ ERROR:", err)
    return json({ error: err.message ?? String(err) }, 500)
  }
})

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

/* =========================
   GOOGLE OAUTH via JWT (WebCrypto)
========================= */
async function getAccessTokenWebCrypto(opts: { clientEmail: string; privateKeyPem: string }) {
  const now = Math.floor(Date.now() / 1000)

  const header = { alg: "RS256", typ: "JWT" }
  const payload = {
    iss: opts.clientEmail,
    sub: opts.clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  }

  const base64url = (input: Uint8Array | string) => {
    const str = typeof input === "string" ? input : String.fromCharCode(...input)
    return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
  }

  const encHeader = base64url(JSON.stringify(header))
  const encPayload = base64url(JSON.stringify(payload))
  const signingInput = `${encHeader}.${encPayload}`

  const key = await importPrivateKeyPkcs8(opts.privateKeyPem)

  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(signingInput),
  )

  const jwt = `${signingInput}.${base64url(new Uint8Array(signature))}`

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })

  if (!resp.ok) {
    const t = await resp.text()
    throw new Error(`Failed to get access token: ${resp.status} ${t}`)
  }

  const data = await resp.json()
  return data.access_token as string
}

async function importPrivateKeyPkcs8(pem: string): Promise<CryptoKey> {
  // Supporte PRIVATE KEY (PKCS8). Si tu as RSA PRIVATE KEY (PKCS1), ça échouera.
  const pemHeader = "-----BEGIN PRIVATE KEY-----"
  const pemFooter = "-----END PRIVATE KEY-----"

  if (!pem.includes(pemHeader) || !pem.includes(pemFooter)) {
    throw new Error("Private key must be in PKCS8 format: BEGIN PRIVATE KEY")
  }

  const b64 = pem.replace(pemHeader, "").replace(pemFooter, "").replace(/\s/g, "")
  const raw = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer

  return await crypto.subtle.importKey(
    "pkcs8",
    raw,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  )
}

/* =========================
   SEND PUSH (FCM v1)
========================= */
async function sendPush(user: any, accessToken: string) {
  try {
    const streak = user.current_streak ?? 0
    const body = MESSAGES[Math.floor(Math.random() * MESSAGES.length)]
    const title = streak > 0 ? `🔥 ${streak} jours de série !` : "MoodTips 💙"

    const payload = {
      message: {
        token: user.fcm_token,
        notification: { title, body },
        webpush: {
          headers: { Urgency: "high" },
          notification: {
            icon: "/icons/Icon-192.png",
            badge: "/icons/Icon-192.png",
            tag: "moodtips-reminder",
          },
          fcm_options: {
            link: "https://risemomentuman-commits.github.io/MoodTips/",
          },
        },
      },
    }

    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      },
    )

    if (!res.ok) {
      const t = await res.text()
      throw new Error(`FCM ${res.status}: ${t}`)
    }

    console.log(`✅ Sent to ${user.id}`)
    return { success: true, user_id: user.id }
  } catch (err: any) {
    console.error(`❌ Failed for ${user.id}`, err)
    return { success: false, user_id: user.id, error: err.message ?? String(err) }
  }
}
