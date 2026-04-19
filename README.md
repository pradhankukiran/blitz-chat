<div align="center">

<img src=".github/banner.svg" alt="BlitzChat" width="440"/>

### Real-time chat, powered by the BEAM.

Phoenix 1.8 · LiveView · Per-room GenServers · REST API · Production-ready

<br>

[![Elixir](https://img.shields.io/badge/Elixir-1.18-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FD4F00?logo=phoenixframework&logoColor=white)](https://phoenixframework.org/)
[![LiveView](https://img.shields.io/badge/LiveView-1.1-FF6B6B)](https://hexdocs.pm/phoenix_live_view/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-metrics-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Sentry](https://img.shields.io/badge/Sentry-integrated-362D59?logo=sentry&logoColor=white)](https://sentry.io/)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.0-6BA539?logo=openapiinitiative&logoColor=white)](https://www.openapis.org/)
[![Tests](https://img.shields.io/badge/tests-60%20passing-success)](#-testing)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## ✨ Features

- **⚡ Instant delivery** — LiveView + PubSub push messages in under 100ms
- **👥 Live presence & typing** — Who's online, who's typing, updated in real time
- **🧠 Per-room OTP** — Each chat room is an isolated, supervised GenServer. Crash-safe, idle-shutdown after 5m
- **🔐 REST API** — OpenAPI 3.0 spec, Swagger UI (dev), Bearer-token auth, scope-enforced endpoints
- **🛡 Rate limiting** — Per-user, per-API-key, per-IP buckets (Hammer + ETS)
- **📊 Full observability** — Prometheus `/metrics`, Sentry error tracking, structured JSON logs, admin LiveDashboard
- **🐳 Deploy anywhere** — Multi-stage Dockerfile + prod `docker-compose` with Caddy (auto-TLS)
- **🚑 Health probes** — `/health` (liveness) and `/ready` (DB + supervisor) for Kubernetes or compose
- **🧪 Tested** — 60 tests covering contexts, GenServers, plugs, REST, and LiveView

## 🧭 Architecture

```
┌─────────────┐     ┌───────────────────────────────────┐     ┌──────────┐
│   Browser   │◄─WS─┤  Phoenix Endpoint (Bandit)        │──►──┤ Postgres │
└─────────────┘     │                                   │     └──────────┘
                    │  Router → Pipelines               │
 REST (Bearer) ────►│   ├─ :browser  (CSP, CSRF, HSTS)  │     ┌──────────┐
                    │   ├─ :api_auth (read scope)       │─────┤  Caddy   │
                    │   └─ :api_auth_write (write)      │     │  (TLS)   │
                    │                                   │     └──────────┘
                    │  RoomSupervisor (DynamicSupv.)    │
                    │   ├─ RoomServer room:a  (GenSrv)  │
                    │   ├─ RoomServer room:b  (GenSrv)  │
                    │   └─ ...                          │
                    │                                   │
                    │  TaskSupervisor   PubSub          │
                    │  Presence         Telemetry       │
                    └───────────────────────────────────┘
```

Each room spawns a named `GenServer` on first use, **persists every message synchronously** (no in-memory buffer, no data loss on crash), broadcasts via `Phoenix.PubSub`, and idle-shuts-down after 5 minutes of silence.

## 🚀 Quick start

### Local development

```bash
git clone https://github.com/pradhankukiran/blitz-chat.git
cd blitz-chat

# Start Postgres
docker compose up -d db

# Install deps, create DB, run migrations, seed
mix setup

# Start the server (IEx for hot reload)
iex -S mix phx.server
```

Open http://localhost:4000 and log in as `alice` (seeded admin), `bob`, or any username. Swagger UI at http://localhost:4000/swaggerui.

### Production (Docker + Caddy auto-TLS)

```bash
cp .env.example .env
# Fill in POSTGRES_PASSWORD, SECRET_KEY_BASE (mix phx.gen.secret), PHX_HOST

docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec app /app/bin/migrate
```

Caddy issues Let's Encrypt certificates automatically on first boot (~30s).

## 📡 REST API

All endpoints versioned under `/api/v1` and require `Authorization: Bearer <api-key>`.

| Method | Path                          | Scope    | Description                          |
|--------|-------------------------------|----------|--------------------------------------|
| GET    | `/rooms`                      | `:read`  | List rooms (paginated, max 100)      |
| GET    | `/rooms/:id`                  | `:read`  | Show a room                          |
| POST   | `/rooms`                      | `:write` | Create a room                        |
| GET    | `/rooms/:room_id/messages`    | `:read`  | List messages in a room              |
| POST   | `/rooms/:room_id/messages`    | `:write` | Send a message (author = key owner)  |
| GET    | `/rooms/:room_id/stats`       | `:read`  | Live per-process stats               |

Errors always use the same envelope:

```json
{ "error": { "code": "validation_failed", "message": "Invalid input", "details": { "body": ["can't be blank"] } } }
```

## 🧩 Project structure

```
lib/
├─ blitz_chat/
│  ├─ accounts/            User schema + context
│  ├─ api_keys/            API key schema + context (scopes, expiry, usage)
│  ├─ chat/                Room, Message, Membership schemas
│  │  ├─ room_server.ex    Per-room GenServer (persist-then-broadcast)
│  │  └─ room_supervisor   DynamicSupervisor with race-safe start
│  └─ release.ex           Release migration tasks (bin/migrate)
└─ blitz_chat_web/
   ├─ controllers/
   │  ├─ api/              REST (versioned /api/v1, FallbackController)
   │  ├─ health_controller  /health + /ready
   │  └─ metrics_controller /metrics (Prometheus)
   ├─ live/                LobbyLive · RoomLive · AdminDashboardLive
   ├─ plugs/               ApiKeyAuth · RateLimit · SecurityHeaders · SetCurrentUser
   └─ router.ex

config/                    config · dev · prod · runtime · test
priv/repo/migrations/      8 migrations (schemas, FKs, indexes, api key hardening)
rel/overlays/bin/          server · migrate (mix release)
test/                      60 tests

Dockerfile   docker-compose.prod.yml   Caddyfile   .env.example
```

## 🧪 Testing

```bash
mix test             # 60 tests, ~1s
mix precommit        # compile --warnings-as-errors + deps.unlock --unused + format + test
```

Coverage includes context functions, changeset validations, **GenServer concurrency** (50-way race test, concurrent sends, idle shutdown), plugs (rate limit, API key auth, scope enforcement, impersonation rejection), REST controllers, and LiveView authorization gates.

## 🔐 Security

| Layer          | Hardening                                                             |
|----------------|-----------------------------------------------------------------------|
| Headers        | CSP, HSTS, Permissions-Policy, Referrer-Policy on every HTML response |
| CSRF           | Enforced on all mutating browser routes                               |
| Transport      | WebSocket-only (longpoll disabled); `check_origin` pinned to PHX_HOST |
| API auth       | Bearer tokens with `:read` / `:write` / `:admin` scopes               |
| API keys       | SHA-256 hashed, prefix-searchable, expiry + revocation + usage tracking |
| Rate limits    | Login (10/min/IP), API writes (10–60/min/key), LiveView events        |
| Mass-assignment| FK fields never cast from user input                                  |
| Admin access   | `/admin`, LiveDashboard, Prometheus `/metrics` all role-gated         |
| Secrets        | Fail-fast on missing `SECRET_KEY_BASE`, `PHX_HOST`, `DATABASE_URL`    |

## 📊 Observability

| Endpoint          | Purpose                                                      |
|-------------------|--------------------------------------------------------------|
| `/health`         | Liveness (200 if process alive)                              |
| `/ready`          | Readiness (DB `SELECT 1` + RoomSupervisor alive, 503 if not) |
| `/metrics`        | Prometheus scrape: Phoenix, Ecto, BEAM, custom room events   |
| `/admin/metrics`  | Phoenix LiveDashboard (admin only)                           |

Errors forward to Sentry when `SENTRY_DSN` is set at runtime. Logs are structured JSON (`LoggerJSON.Formatters.Basic`) in prod, plain text in dev.

## 🛣 Roadmap

- [ ] Message edit / delete
- [ ] File and image uploads
- [ ] Markdown rendering with sanitization
- [ ] Email / OAuth authentication (currently username-only)
- [ ] Redis backend for rate limiting (horizontal scale)
- [ ] End-to-end encryption
- [ ] GitHub Actions CI pipeline

## 📄 License

[MIT](LICENSE) © Kiran Pradhan
