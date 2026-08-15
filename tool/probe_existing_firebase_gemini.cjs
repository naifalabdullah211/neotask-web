const fs = require('node:fs');

async function main() {
  const source = fs.readFileSync('lib/firebase_options.dart', 'utf8');
  const match = source.match(/static const FirebaseOptions web = FirebaseOptions\([\s\S]*?apiKey:\s*'([^']+)'/);
  if (!match) throw new Error('firebase-web-api-key-not-found');
  const key = match[1];
  const models = ['gemini-3.5-flash-lite', 'gemini-3.5-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-flash'];
  const results = [];
  for (const model of models) {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        contents: [{role: 'user', parts: [{text: 'Reply with exactly OK'}]}],
        generationConfig: {maxOutputTokens: 8, temperature: 0},
      }),
      signal: AbortSignal.timeout(20000),
    });
    const body = await response.json().catch(() => ({}));
    const reply = body?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    const errorCode = body?.error?.status || body?.error?.code || null;
    results.push({model, status: response.status, ok: response.ok, errorCode, replyIsOk: reply.trim() === 'OK'});
    if (response.ok) break;
  }
  console.log(JSON.stringify(results));
  if (!results.some((item) => item.ok && item.replyIsOk)) process.exitCode = 1;
}

main().catch((error) => {
  console.log(JSON.stringify({ok: false, error: error.name || 'error'}));
  process.exitCode = 1;
});
