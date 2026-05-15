# AutoMyInvoice

Elixir/Phoenix LiveView 기반 자동 송장 리마인더 SaaS 모노레포 (Web · Android · iOS).

## Quick start

### Option A · Docker (recommended; no host Elixir required)

```bash
cp .env.example .env            # 기본값 그대로 사용해도 OK

make docker.build               # dev 이미지 빌드
make docker.setup               # mix setup (deps + DB create/migrate + seeds + assets)
make docker.test                # 전체 테스트 실행
make docker.precommit           # 커밋 전 검증 (compile --warnings-as-errors + format + test)
make docker.server              # http://localhost:4000 에서 Phoenix 기동
```

기본값:

- Postgres는 컨테이너 내부에서는 `db:5432`, 호스트에서는 `localhost:15432` 로 노출됩니다.
- Phoenix는 컨테이너 내부에서 `0.0.0.0` (env `PHX_HOST_BIND`)로 바인딩하므로 호스트의 `localhost:4000`로 접근 가능합니다.
- 모든 `make docker.*` 타깃은 호스트의 UID/GID를 컨테이너에 전달해 마운트된 파일이 root 소유로 바뀌는 문제를 방지합니다.

데이터 리셋:

```bash
make docker.down
docker volume rm auto-my-invoice_postgres_data   # 필요 시
```

### Option B · Native (host에 Elixir/Postgres가 있을 때)

```bash
./scripts/setup.sh   # mix deps.get + ecto.setup + assets
make server          # mix phx.server
make test
make precommit
```

native 환경에서는 `config/dev.exs`/`config/test.exs`가 `POSTGRES_*` env가 없으면 `localhost:5432` + 현재 시스템 사용자명으로 폴백합니다.

## Learn more

* Phoenix: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Source: https://github.com/phoenixframework/phoenix
