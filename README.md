# Qyra

AI hosts from around the world who come online on their own local time.
Every host is an AI character, aged 18+.

## What lives where
- `index.html`, `favicon.svg`, `manifest.webmanifest`, `icons/` : the Qyra app (also the website).
- `admin.html` : Qyra Admin. It holds no data. It loads your hosts from your PRIVATE repo `qyra-admin` using a token stored only on your phone.
- `hosts.json`, `photos/` : written by the Publish button in Qyra Admin. App updates never include them.
- `apps/`, `.github/workflows/build.yml` : GitHub Actions builds two APKs from these: `qyra-apk` and `qyra-admin-apk` (Actions tab, open the latest run, Artifacts).
- `tools/setup_signing.sh` : run once in Termux to create the permanent signing key.

Image prompts are kept only in the private `qyra-admin` repo. Never upload a `qyra-admin-backup.zip` here.
