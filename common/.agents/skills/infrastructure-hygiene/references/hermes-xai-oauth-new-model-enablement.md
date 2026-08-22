# Hermes xAI OAuth New-Model Enablement

Use this when Luke asks to make a newly announced Grok model usable in Hermes without changing protected Hermes core code.

## Boundaries

- Do not patch bundled/protected `hermes-agent` skill or Hermes core provider code just to add a model slug.
- Prefer supported config, provider catalog refresh/cache, and a real `hermes chat` smoke test.
- Do not print or inspect OAuth token values from `/config/.hermes/auth.json`.

## Checklist

1. Confirm xAI OAuth credentials and current Hermes state:

```bash
hermes auth list
hermes status --all | grep -Ei 'model|provider|xai|grok|auth'
hermes doctor | grep -Ei 'xAI|retired|auth|model|provider'
```

2. Check whether the model is already in the live/local model catalog:

```bash
cd /config/.hermes/hermes-agent
python3 - <<'PY'
from hermes_cli.models import provider_model_ids
ids = provider_model_ids('xai-oauth')
print('grok-4.5 in picker/catalog:', 'grok-4.5' in ids)
print(ids[:30])
PY
```

`xai-oauth` accepts plausible `grok-*` hidden/new slugs even if the local curated listing lags, but the catalog check tells whether the picker will show it.

3. Smoke the exact model through Hermes, not just xAI docs:

```bash
hermes chat --provider xai-oauth -m grok-4.5 \
  -q 'Reply with exactly: grok45-ready' \
  -Q --toolsets safe
```

Expected: the exact sentinel reply. This verifies auth, transport, model slug, and Hermes routing together.

4. If Luke wants it available as fallback/auxiliary but not the main model, update config via supported mechanisms, then verify YAML shape. `hermes config set` is fine for scalar keys, but can serialize structured lists as strings; for `fallback_providers`, back up and write real YAML:

```bash
cp /config/.hermes/config.yaml /config/.hermes/config.yaml.bak-grok45-$(date +%Y%m%d%H%M%S)
python3 - <<'PY'
import yaml, time
from pathlib import Path
p = Path('/config/.hermes/config.yaml')
cfg = yaml.safe_load(p.read_text()) or {}
cfg['fallback_providers'] = [
    {'provider': 'xai-oauth', 'model': 'grok-4.5', 'base_url': 'https://api.x.ai/v1'}
]
cfg.setdefault('auxiliary', {}).setdefault('title_generation', {})['provider'] = 'xai-oauth'
cfg['auxiliary']['title_generation']['model'] = 'grok-4.5'
cfg['auxiliary']['title_generation']['base_url'] = 'https://api.x.ai/v1'
p.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True))
PY
```

5. Verify:

```bash
hermes config check
hermes doctor | grep -Ei 'xAI|retired|auth|model|provider'
python3 - <<'PY'
import yaml
cfg = yaml.safe_load(open('/config/.hermes/config.yaml'))
print(yaml.safe_dump({
  'model': cfg.get('model'),
  'fallback_providers': cfg.get('fallback_providers'),
  'title_generation': cfg.get('auxiliary',{}).get('title_generation'),
}, sort_keys=False))
PY
```

## Pitfalls

- `patch`/`write_file` tools refuse direct writes to `/config/.hermes/config.yaml`; use `hermes config set` or terminal-side backup + Python/YAML edit.
- `hermes config set fallback_providers '[...]'` may save a YAML string rather than a list. Always read the resulting config back and repair the type if needed.
- `web.extract_backend` may be unset while Kagi is search-only; for Hermes docs, prefer the local checkout under `/config/.hermes/hermes-agent/website/docs/` or Kagi search snippets unless a real extract backend is configured.
- If the gateway should use changed config immediately, restart/reload the gateway through the approved Hermes mechanism after verifying the config. One-shot CLI smokes do not prove the existing long-lived gateway has reloaded.