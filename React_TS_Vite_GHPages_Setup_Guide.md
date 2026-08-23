# React + TS + Vite + GitHub Pages: Locked Setup Guide
 
This guide scaffolds a new project — or re-pins an existing one — to a
specific, verified-working version set. It intentionally avoids `vite@8.x`.
 
## Why these versions are locked
 
`vite@8.x` ships Rolldown (a Rust-based bundler) as its default production
build engine, replacing the previous Rollup + esbuild pipeline. As of this
writing it carries a confirmed, actively-tracked regression: every 8.x
release shows roughly 7× higher memory footprint than the 7.x
rollup/esbuild pipeline, with no within-8.x patch resolving it
([rolldown/rolldown#9330](https://github.com/rolldown/rolldown/issues/9330)).
In practice this surfaces as production builds that take minutes instead of
seconds — heavy thread-lock contention inside Vite's internal
`vite:prepare-out-dir` build step, even on small projects with tiny output.
 
This guide pins to the last known-good pre-Rolldown line:
 
| Package | Version | Why |
|---|---|---|
| `vite` | `7.3.6` | Last stable line before Rolldown became the default bundler |
| `@vitejs/plugin-react` | `4.3.4` | The `6.x` line requires Vite 8's `./internal` export subpath and will fail to resolve against Vite 7 |
| `typescript` | `~5.9.3` | Stable, unrelated to the Vite 8 issue — pinned only for reproducibility |
 
If the upstream memory regression is later fixed, re-evaluate — this lock
is a deliberate, temporary trade of "latest" for "predictable iteration
time," not a permanent ceiling.
 
---
 
## 1. Scaffold
 
```
npm create vite@latest my-project -- --template react-ts
cd my-project
```
 
Immediately override the versions the scaffold installs — see step 2.
 
## 2. Lock `package.json`
 
```json
{
  "name": "my-project",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "type-check": "tsc --noEmit",
    "lint": "oxlint",
    "preview": "vite preview",
    "deploy": "npm run build && gh-pages -d dist"
  },
  "dependencies": {
    "react": "^19.2.8",
    "react-dom": "^19.2.8",
    "react-router-dom": "^6.28.0"
  },
  "devDependencies": {
    "@types/node": "^24.13.3",
    "@types/react": "^19.2.17",
    "@types/react-dom": "^19.2.3",
    "@vitejs/plugin-react": "4.3.4",
    "autoprefixer": "^10.4.20",
    "gh-pages": "^6.3.0",
    "oxlint": "^1.75.0",
    "sass": "^1.83.0",
    "typescript": "~5.9.3",
    "vite": "7.3.6"
  },
  "browserslist": [
    "last 2 versions",
    "> 5%",
    "Firefox ESR"
  ]
}
```
 
`@vitejs/plugin-react` and `vite` are pinned to **exact** versions
(no `^`) deliberately — both are the pair responsible for the regression
above, so they should never silently float to a newer major on a routine
`npm install`. Everything else can use `^` normally.
 
```
rm -rf node_modules package-lock.json
npm install
```
 
## 3. `vite.config.ts` — GH Pages SPA support
 
`react-router-dom`'s client-side routing breaks on a hard refresh or direct
link to any route other than `/`, since GitHub Pages has no server-side
rewrite. This plugin generates a static `index.html` copy per route plus a
`404.html` fallback at build time.
 
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { copyFileSync, mkdirSync } from 'fs';
import { resolve } from 'path';
 
// Update this list to match every <Route path="..."> in App.tsx,
// excluding the "*" catch-all.
const routes: string[] = [];
 
export default defineConfig({
  // '/' for a custom domain or user page (username.github.io).
  // '/repo-name/' for a project page with no custom domain.
  base: '/',
  plugins: [
    react(),
    {
      name: 'gh-pages-spa-routes',
      closeBundle() {
        for (const route of routes) {
          mkdirSync(resolve('dist', route), { recursive: true });
          copyFileSync(resolve('dist/index.html'), resolve('dist', route, 'index.html'));
        }
        copyFileSync(resolve('dist/index.html'), resolve('dist/404.html'));
      },
    },
  ],
});
```
 
## 4. `postcss.config.js` — autoprefixer
 
```javascript
export default {
  plugins: {
    autoprefixer: {},
  },
};
```
 
Reads its target browser list from the `browserslist` field in
`package.json` (already set in step 2) — no separate config needed.
 
## 5. `public/CNAME` — only if using a custom domain
 
```
your-domain.com
```
 
Vite copies `public/` into `dist/` verbatim on every build, so this file
persists across every `npm run deploy`. Skip this file entirely for a
default `username.github.io/repo-name/` deploy — but if you skip it, set
`base: '/repo-name/'` in `vite.config.ts` instead of `'/'`.
 
## 6. `src/App.tsx` — routing owns the top level
 
```tsx
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
 
import './styles/main.scss'; // if using Sass — see step 7
 
export default function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={/* ... */} />
        {/* one <Route> per entry in vite.config.ts's routes array */}
        <Route path="*" element={/* 404 element */} />
      </Routes>
    </Router>
  );
}
```
 
## 7. `src/main.tsx` — stays minimal
 
```tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
 
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```
 
`BrowserRouter` and the global stylesheet import both live in `App.tsx`,
not here — keeps `main.tsx` a pure bootstrap file.
 
## 8. Verify the lock took effect
 
```
npx vite -v
```
 
Should print `vite/7.3.6`, not `8.x`. If it doesn't, `node_modules` still
has a stale install — re-run the `rm -rf` + `npm install` from step 2.
 
## 9. Deploy
 
```
npm run deploy
```
 
Runs `npm run build` then pushes `dist/` to the `gh-pages` branch via the
`gh-pages` CLI. Confirm the repo's GitHub Pages settings point at that
branch (Settings → Pages → Source → `gh-pages` branch, root).