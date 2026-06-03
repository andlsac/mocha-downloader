# Security Policy / Política de Segurança

## Reporting / Reportar

Found a vulnerability? Open a **private security advisory** on this repo or
email the maintainer. Please do **not** open a public issue for security bugs.

Encontrou uma falha? Abra um **security advisory** privado ou contate o
mantenedor. Não use issues públicas para vulnerabilidades.

---

## Verifying releases / Verificando releases

Each release ships:

| File | Purpose |
|------|---------|
| `Mocha-x.y.z.dmg`        | The app disk image |
| `Mocha-x.y.z.dmg.sha256` | SHA-256 checksum |
| `Mocha-x.y.z.dmg.sig`    | SSH detached signature |
| `mocha_signing_key.pub`  | Public key to verify the signature |

```sh
# 1. Checksum
shasum -a 256 -c Mocha-x.y.z.dmg.sha256

# 2. Signature (Ed25519, SSH format)
echo 'KEY_CONTENTS  mocha-release' > allowed_signers   # or use the .pub provided
ssh-keygen -Y verify -f allowed_signers -I mocha-release \
  -n file -s Mocha-x.y.z.dmg.sig < Mocha-x.y.z.dmg
```

Commits and tags are also signed with the same Ed25519 SSH key.

> Note: the `.app` is **ad-hoc codesigned** (no paid Apple Developer ID), so it
> is **not** Apple-notarized. Trust comes from the checksum + SSH signature
> above, not from Gatekeeper.

---

## Hardening applied / Proteções aplicadas

Mocha was rebuilt from a reverse-engineered MIT app. The original's unsafe
patterns were removed:

- **No shell command injection** — `yt-dlp` runs via `Process` with an argument
  array and an absolute executable path; URLs are never interpolated into a
  shell string. The original used `/bin/sh` + `curl -L … -o yt-dlp` + `chmod a+x`.
- **TLS-enforced backend download** — `yt-dlp` is fetched with `URLSession`
  (ATS), not `curl`, with an HTTP-status check.
- **Owner-only backend** — installed to `~/Library/Application Support/Mocha`
  with `0700` permissions (not a world-executable `./yt-dlp`).
- **URL scheme validation** — only `http`/`https` links are accepted, in the UI,
  the `mocha://` URL handler, and before every subprocess call.
- **No telemetry / no network** beyond yt-dlp, ffmpeg detection, thumbnails and
  the one-time backend download.

PT-BR: sem injeção de comando, download do backend via TLS, backend só do dono
(0700), validação de esquema de URL e nenhuma telemetria.

---

## Cookies

When you enable cookies, Mocha passes `--cookies-from-browser` or `--cookies`
to yt-dlp locally. Cookies are **never** transmitted anywhere by Mocha; they go
straight to the yt-dlp subprocess on your machine.
