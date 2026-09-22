# zilloris.com

The studio's website: every app in one place, in the studio's own look (the same
tokens and fonts as the Shelf and the channel covers).

## What it costs: nothing

| Piece | Choice | Price |
|---|---|---|
| Pages | Plain HTML and CSS, no framework, no JavaScript | free |
| Hosting | GitHub Pages, from this repo's `docs/` folder | free |
| HTTPS | GitHub's certificate for the custom domain | free |
| Fonts | Served from this site, not from Google | free, and no visitor data leaves |
| Analytics | None, so no cookies and no consent banner | free |
| Domain + email | Stay exactly where they are, on Hostinger | what you already pay |

Why GitHub Pages rather than Cloudflare Pages (also free, and faster): Cloudflare
can only serve the bare `zilloris.com` if the nameservers move to Cloudflare, and
that move is where `support@zilloris.com` breaks if one mail record is missed.
GitHub Pages needs only a few records *added* at Hostinger - nothing about email
is touched. If you ever do move DNS to Cloudflare, `docs/` works there unchanged.

## Change something

```bash
powershell -ExecutionPolicy Bypass -File build.ps1    # rebuilds docs/
powershell -ExecutionPolicy Bypass -File serve.ps1    # preview at http://localhost:8765
```

- **Add or change an app:** edit `apps.json`, rebuild. Every line is public, so it
  follows the claim rules - say what the app is for, never a feature the shipped
  build does not have. Only apps with a build on Google Play are shown: set
  `onPlay` to `true` the day an app's first build goes up, and rebuild.
- **Change the page:** edit `src/`, rebuild. Never edit `docs/`; the build deletes it.

`docs/` is committed because GitHub Pages can only serve what is in the repo. The
icons and fonts in it are copies: the originals stay in each app's repo and
`build.ps1` copies them in fresh every time.

## Put it live (one time)

### 1. GitHub

1. On github.com, create a **public** repository, e.g. `maisamhaider/zilloris-site`.
   (GitHub Pages is free only for public repositories.)
2. Push this repo to it:
   ```bash
   git remote add origin https://github.com/maisamhaider/zilloris-site.git
   git push -u origin main
   ```
3. Repository **Settings → Pages**: Source *Deploy from a branch*, branch `main`,
   folder `/docs`. Save.
4. Same page, **Custom domain**: `zilloris.com`. (The `CNAME` file already says it.)
5. Your GitHub **Settings → Pages → Verified domains**: verify `zilloris.com`, so no
   one else can ever point a GitHub site at it.

### 2. Hostinger DNS (hPanel → Domains → zilloris.com → DNS / Nameservers)

**Leave every MX and TXT record alone.** They are what deliver `support@zilloris.com`.

| Action | Type | Name | Points to |
|---|---|---|---|
| Delete | A | `@` | `2.57.91.91` (Hostinger's parking page) |
| Delete | AAAA | `@` | if one exists |
| Add | A | `@` | `185.199.108.153` |
| Add | A | `@` | `185.199.109.153` |
| Add | A | `@` | `185.199.110.153` |
| Add | A | `@` | `185.199.111.153` |
| Change to CNAME | CNAME | `www` | `maisamhaider.github.io` |

### 3. Wait, then lock it

DNS can take from minutes to a few hours. When GitHub's Pages settings show the
domain as working, tick **Enforce HTTPS**. Then send yourself a test email at
`support@zilloris.com` to confirm mail still arrives.

## Each app's About, Privacy and Terms

Apps with `"pages": true` in `apps.json` get three pages, each in that app's own
look (`src/themes/<id>.css`, fonts from the app's repo):

| Page | Address | Source |
|---|---|---|
| About | `zilloris.com/<id>/` | `content/<id>/about.html` |
| Privacy | `zilloris.com/<id>/privacy/` | `content/<id>/privacy.html` |
| Terms | `zilloris.com/<id>/terms/` | `content/<id>/terms.html` |

**To update a policy:** edit `content/<id>/privacy.html` (plain HTML: `<h2>`, `<p>`,
`<ul>`, `<a>`), change its "Updated" date, rebuild, commit, push. It is live in
about a minute. The address never changes, so nothing in the app or Play Console
needs touching - no Remote Config, no new build.

- The first line, `<!-- title: App - Privacy Policy -->`, sets the page heading.
  Leading lines that only repeat the title are dropped from the page, since the
  heading already says them.
- The policies were imported word for word from the Blogger posts on 22 Sep 2026
  (`tools/import-blogger.ps1`, which checks the text matches). From then on these
  files are the source. The Blogger posts are left up and are not updated.
- A policy's text is never retyped by hand from memory; change only what changed.
- About pages follow the claim rules: only what the shipped build does.

**Switching an app to these addresses** (once per app): put the new Privacy URL in
Play Console (App content → Privacy policy; takes effect at once), and the new
links in the app's next build. Apps that bundle their own copy of the policy
(Manuscript's `assets/legal`, Note Bolt's `privacy_policy_body`) only update that
copy with a build. Keep the Blogger posts up until every installed copy links here.

## Later, when needed

- **An app outgrows its card:** give it `zilloris.com/app-name/`, or a subdomain
  (`app-name.zilloris.com`, one CNAME record to `maisamhaider.github.io` plus its own
  repo) if it needs a whole site of its own.
- **Android App Links:** `docs/.well-known/assetlinks.json` can vouch for every app
  at once. It needs each app's signing-certificate SHA-256 from Play Console, so it
  is not guessed here. `.nojekyll` is already in place so GitHub will serve it.
- **Nightbook's icon:** none exists yet as a file, so its card shows a letter. Add the
  path to `apps.json` once the icon is exported.
