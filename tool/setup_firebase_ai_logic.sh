#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID='neotask1-ff5a4'
PROJECT_NUMBER='4737825788'
GEMINI_KEY_ID='neotask-firebase-ai-logic'
GEMINI_KEY_RESOURCE="projects/${PROJECT_NUMBER}/locations/global/keys/${GEMINI_KEY_ID}"
GEMINI_KEY_DISPLAY='NeoTask Firebase AI Logic Gemini Key'
WEB_API_KEY='AIzaSyAH4nvOmEuBXlYmSgTvVedEyGGqcVhXcZ4'

: "${GOOGLE_APPLICATION_CREDENTIALS:?missing GOOGLE_APPLICATION_CREDENTIALS}"
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS" --quiet >/dev/null
gcloud config set project "$PROJECT_ID" --quiet >/dev/null

echo 'Enabling Firebase AI Logic dependencies...'
gcloud services enable \
  serviceusage.googleapis.com \
  apikeys.googleapis.com \
  generativelanguage.googleapis.com \
  firebasevertexai.googleapis.com \
  --project="$PROJECT_ID" --quiet >/dev/null

if ! gcloud services api-keys describe "$GEMINI_KEY_RESOURCE" --project="$PROJECT_ID" --quiet >/dev/null 2>&1; then
  echo 'Creating restricted Gemini Developer API key for Firebase AI Logic...'
  gcloud services api-keys create \
    --project="$PROJECT_ID" \
    --key-id="$GEMINI_KEY_ID" \
    --display-name="$GEMINI_KEY_DISPLAY" \
    --api-target=service=generativelanguage.googleapis.com \
    --quiet >/dev/null
else
  echo 'Reusing existing NeoTask Firebase AI Logic Gemini key...'
fi

# Re-apply the only permitted API target. Firebase documentation explicitly
# recommends no application restrictions on this proxy-owned Gemini key.
gcloud services api-keys update "$GEMINI_KEY_RESOURCE" \
  --project="$PROJECT_ID" \
  --api-target=service=generativelanguage.googleapis.com \
  --quiet >/dev/null

GEMINI_KEY_STRING="$(gcloud services api-keys get-key-string "$GEMINI_KEY_RESOURCE" --project="$PROJECT_ID" --format='value(keyString)')"
if [[ -z "$GEMINI_KEY_STRING" ]]; then
  echo 'Gemini key string retrieval failed' >&2
  exit 1
fi

ACCESS_TOKEN="$(gcloud auth print-access-token)"
export GEMINI_KEY_STRING
python - <<'PY' > "$RUNNER_TEMP/firebase-ai-config.json"
import json, os
print(json.dumps({'generativeLanguageConfig': {'apiKey': os.environ['GEMINI_KEY_STRING']}}))
PY
curl --silent --show-error --fail \
  -X PATCH \
  -H "x-goog-user-project: ${PROJECT_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  "https://firebasevertexai.googleapis.com/v1beta/projects/${PROJECT_ID}/locations/global/config" \
  --data-binary @"$RUNNER_TEMP/firebase-ai-config.json" \
  > "$RUNNER_TEMP/firebase-ai-config-response.json"
unset GEMINI_KEY_STRING
rm -f "$RUNNER_TEMP/firebase-ai-config.json"

python - <<'PY'
import json, os
path = os.path.join(os.environ['RUNNER_TEMP'], 'firebase-ai-config-response.json')
with open(path, encoding='utf-8') as f:
    data = json.load(f)
# Never print any key material. Only assert the config resource was returned.
if not isinstance(data, dict):
    raise SystemExit('Firebase AI Logic config response invalid')
print('Firebase AI Logic Gemini backend config: configured')
PY
rm -f "$RUNNER_TEMP/firebase-ai-config-response.json"

# Firebase API keys created for web apps may already carry an API allowlist.
# Firebase AI Logic must be added if such an allowlist exists. If the key is
# unrestricted, leave it unrestricted rather than accidentally narrowing it.
WEB_KEY_RESOURCE="$(gcloud services api-keys lookup "$WEB_API_KEY" --project="$PROJECT_ID" --format='value(name)')"
if [[ -z "$WEB_KEY_RESOURCE" ]]; then
  echo 'Could not resolve Firebase web API key resource' >&2
  exit 1
fi

gcloud services api-keys describe "$WEB_KEY_RESOURCE" --project="$PROJECT_ID" --format=json > "$RUNNER_TEMP/web-api-key.json"
WEB_KEY_STATE="$(python - <<'PY'
import json, os
with open(os.path.join(os.environ['RUNNER_TEMP'], 'web-api-key.json'), encoding='utf-8') as f:
    data = json.load(f)
targets = data.get('restrictions', {}).get('apiTargets')
if not targets:
    print('unrestricted')
elif any(t.get('service') == 'firebasevertexai.googleapis.com' for t in targets):
    print('ready')
else:
    print('append')
PY
)"
rm -f "$RUNNER_TEMP/web-api-key.json"

case "$WEB_KEY_STATE" in
  append)
    echo 'Adding Firebase AI Logic API to existing Firebase web API-key allowlist...'
    gcloud alpha services api-keys update "$WEB_KEY_RESOURCE" \
      --project="$PROJECT_ID" \
      --append \
      --api-target=service=firebasevertexai.googleapis.com \
      --quiet >/dev/null
    ;;
  ready)
    echo 'Firebase web API-key allowlist already includes Firebase AI Logic API.'
    ;;
  unrestricted)
    echo 'Firebase web API key is unrestricted; no allowlist update needed.'
    ;;
  *)
    echo "Unexpected Firebase web API key state: $WEB_KEY_STATE" >&2
    exit 1
    ;;
esac

for service in generativelanguage.googleapis.com firebasevertexai.googleapis.com; do
  if ! gcloud services list --enabled --project="$PROJECT_ID" --filter="config.name=${service}" --format='value(config.name)' | grep -qx "$service"; then
    echo "Required service not enabled: $service" >&2
    exit 1
  fi
done

echo 'NeoTask Firebase AI Logic setup verified.'
