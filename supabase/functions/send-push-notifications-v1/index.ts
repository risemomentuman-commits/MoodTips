// supabase/functions/send-push-notifications-v1/index.ts
// Version compatible Deno - Sans bibliothèques externes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const MESSAGES = [
  "Comment te sens-tu en ce moment ? 🌿",
  "Prends un instant pour toi 💙",
  "Un petit check-in ? 😊",
  "Comment va ton humeur aujourd'hui ? ✨",
  "Et toi, comment ça va ? 🍃",
]

serve(async (req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    
    const { data: users, error } = await supabase
      .rpc('get_users_to_notify_push')
    
    if (error) throw error
    
    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No users to notify' }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`Sending push to ${users.length} users`)
    
    // Obtenir access token
    const accessToken = await getAccessToken()
    
    // Envoyer notifications
    const results = await Promise.all(
      users.map(user => sendPush(user, accessToken))
    )
    
    const successful = results.filter(r => r.success).length
    
    return new Response(
      JSON.stringify({ 
        message: `Sent ${successful}/${users.length} notifications`,
        results 
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

// Générer un access token OAuth2 avec Web Crypto API
async function getAccessToken(): Promise<string> {
  try {
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT)
    
    // Créer le JWT
    const now = Math.floor(Date.now() / 1000)
    
    const header = {
      alg: 'RS256',
      typ: 'JWT',
    }
    
    const payload = {
      iss: serviceAccount.client_email,
      sub: serviceAccount.client_email,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    }
    
    // Encoder en base64url
    const base64url = (input: Uint8Array | string): string => {
      const str = typeof input === 'string' 
        ? input 
        : String.fromCharCode(...input)
      
      return btoa(str)
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '')
    }
    
    const headerEncoded = base64url(JSON.stringify(header))
    const payloadEncoded = base64url(JSON.stringify(payload))
    const signatureInput = `${headerEncoded}.${payloadEncoded}`
    
    // Importer la clé privée
    const privateKey = await importPrivateKey(serviceAccount.private_key)
    
    // Signer
    const encoder = new TextEncoder()
    const data = encoder.encode(signatureInput)
    const signatureBuffer = await crypto.subtle.sign(
      { name: 'RSASSA-PKCS1-v1_5' },
      privateKey,
      data
    )
    
    const signatureEncoded = base64url(new Uint8Array(signatureBuffer))
    const jwt = `${signatureInput}.${signatureEncoded}`
    
    // Échanger le JWT contre un access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })
    
    if (!tokenResponse.ok) {
      const error = await tokenResponse.text()
      throw new Error(`Failed to get access token: ${error}`)
    }
    
    const tokenData = await tokenResponse.json()
    return tokenData.access_token
    
  } catch (error) {
    console.error('Error getting access token:', error)
    throw error
  }
}

// Importer la clé privée RSA
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Extraire le contenu de la clé PEM
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = pem
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '')
  
  // Décoder base64
  const binaryString = atob(pemContents)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  
  // Importer la clé
  return await crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )
}

// Envoyer une notification via FCM API V1
async function sendPush(user: any, accessToken: string) {
  try {
    const firstName = user.full_name?.split(' ')[0] || 'ami'
    const streak = user.current_streak || 0
    const randomMessage = MESSAGES[Math.floor(Math.random() * MESSAGES.length)]
    
    let title = 'MoodTips 💙'
    if (streak > 0) {
      title = `🔥 ${streak} jours de série !`
    }
    
    const payload = {
      message: {
        token: user.fcm_token,
        notification: {
          title: title,
          body: randomMessage,
        },
        webpush: {
          headers: { Urgency: 'high' },
          notification: {
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
            tag: 'moodtips-reminder',
            requireInteraction: false,
          },
          fcm_options: {
            link: 'https://risemomentuman-commits.github.io/MoodTips/',
          },
        },
      },
    }
    
    const url = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    })
    
    if (!response.ok) {
      const error = await response.text()
      throw new Error(`FCM error: ${response.status} - ${error}`)
    }
    
    const result = await response.json()
    console.log(`✅ Sent to ${firstName}`)
    
    return { success: true, user: firstName }
    
  } catch (error) {
    console.error(`❌ Failed for ${user.full_name}:`, error)
    return { success: false, user: user.full_name, error: error.message }
  }
}