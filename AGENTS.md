# AGENTS.md

One-page brief for any AI coding agent working in this repo. Read this before proposing or making changes.

## Stack
- **Rails 8.1** (`~> 8.1.3`) sample Todo app, Ruby 3.4 (see `.ruby-version`).
- **Database:** SQLite 3 (`sqlite3 >= 2.1`) for all environments.
- **View layer:** Hotwire (Turbo + Stimulus via `turbo-rails` / `stimulus-rails`), ERB templates, JavaScript through `importmap-rails` (no Node/Webpack build). No CSS framework — plain `app/assets/stylesheets/application.css` served by Propshaft.
- **Test framework:** Minitest (Rails default, in `test/`), with Capybara + Selenium for system tests. There is **no RSpec** in this project.
- **Background jobs / infra:** Solid Queue (jobs), Solid Cache, Solid Cable — all database-backed. No Redis.

## Commands
- Setup / install deps + prepare DB: `bin/setup` (or `bin/setup --skip-server`)
- Run the dev server: `bin/dev` (alias for `bin/rails server`)
- Run the full test suite: `bin/rails test` (system tests: `bin/rails test:system`)
- Run a single test file: `bin/rails test test/controllers/todos_controller_test.rb`
- Prepare the test database: `bin/rails db:test:prepare`
- Lint: `bin/rubocop` (config in `.rubocop.yml`, rubocop-rails-omakase)
- Security scan: `bin/brakeman`

## Conventions
- **Naming:** standard Rails conventions — singular models (`Todo`), plural RESTful controllers (`TodosController`), snake_case files matching class names.
- **Controllers:** RESTful `resources :todos`. Actions use `respond_to` blocks for `format.html` and `format.json`; prefer adding `format.turbo_stream` for in-place updates over custom JS. Strong parameters live in private `*_params` methods using `params.expect(...)`.
- **Authorization:** there is currently **no authentication/authorization layer** (no Devise, no `current_user`). Do not invent one without explicit approval; if a story requires it, propose it first.
- **Views / partials:** per-record partials live in `app/views/todos/` (e.g. `_todo.html.erb`, `_form.html.erb`); JSON via jbuilder (`_todo.json.jbuilder`). Wrap each record in `dom_id(todo)` so Turbo Streams can target it.
- **Migrations:** generate with `bin/rails generate migration ...`; keep them reversible; update `db/schema.rb` by running migrations, never by hand.

## Don'ts
- **No new gems without approval.** The current Gemfile is intentionally minimal.
- **No inline JavaScript in ERB.** Use Stimulus controllers (`app/javascript/controllers/`) or Turbo Streams instead.
- **Do not disable Rails safety mechanisms** — no `skip_before_action :verify_authenticity_token`, no disabling CSRF or mass-assignment protection.
- **Do not seed or hardcode real user data.** Use `db/seeds.rb` and test fixtures (`test/fixtures/todos.yml`) only.
- **Do not introduce RSpec or another test framework** — write Minitest tests under `test/`.
- **Do not import models, migrations, or schema from other projects.** Keep the schema scoped to this todo app.
