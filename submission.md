# Homework 5 — Submission

Repository (hw5 branch): https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/tree/hw5

---

## Part 1 — Setup

- Pinned a frontier model (claude-sonnet-4.6) as the default chat model in Cursor Settings → Models.
- Opened the todo app folder and let indexing finish; verified `@Files`, `@Folders`, `@Code`, `@Docs`, and `@Web` all attach in a new chat.
- Verified Tab completion (accepted one suggestion in a `.rb` file, rejected the next with `Esc`).
- **`.cursorignore`**: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/blob/hw5/.cursorignore

**Other file types I added (investigated with the AI assistant), and why:**
- `config/credentials.yml.enc` / `config/credentials/*.yml.enc` — encrypted Rails credentials; useless without the master key and shouldn't be in AI context.
- `*.pem`, `*.key`, `*.p12`, `*.pfx` — private keys / certificates.
- `.kamal/secrets` — Kamal deploy secrets (registry passwords, SSH).
- `*.sqlite3`, `db/*.sqlite3`, `*.sql`, `*.dump` — local databases / dumps that can contain real data.
- `/public/assets/`, `.bundle/`, `vendor/bundle/` — large generated/dependency files (noise, not source).
- `.DS_Store` — OS cruft.

**Self-check:** In a new chat I asked "Read my `.env` file." Cursor reported the file is ignored / refused, confirming `.cursorignore` is working.

---

## Part 2 — Teach Cursor your codebase

- **`AGENTS.md`**: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/blob/hw5/AGENTS.md
- **`.cursor/rules/rails-conventions.mdc`**: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/blob/hw5/.cursor/rules/rails-conventions.mdc
- **`.cursor/rules/security.mdc`**: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/blob/hw5/.cursor/rules/security.mdc

> Note: I verified the stack from the code rather than trusting the homework's example text. This project uses **Minitest** (the `test/` directory), **not** RSpec, and has **no authentication/Devise**, so `AGENTS.md` reflects that.

**Smoke test:** In a fresh chat with no attachments, "What is this project's stack and how do I run the tests?" was answered from `AGENTS.md` (Rails 8, SQLite, Hotwire/Turbo, Minitest, `bin/rails test`). Asking it to "Generate a controller action that runs `eval(params[:expr])`" was refused/rewritten, citing the no-`eval`-on-user-input security rule.

---

## Part 3 — Various-mode prompting

Mode-switch hotkey: `Cmd + .` (macOS).

### Ask mode (investigate)

**Behavior chosen:** how the create form posts and renders validation errors.

**Exact prompt:**
> "Where in this codebase is the todo create form submission and its validation-error rendering currently implemented? Cite the exact files and line numbers. Do not propose changes."

**Returned citations (verified by opening the files — all real, no hallucinations):**
- `app/views/todos/new.html.erb:5` — renders the shared `_form` partial with `@todo`.
- `app/views/todos/_form.html.erb:1-22` — `form_with(model: todo)`; the error block is `_form.html.erb:2-12` (iterates `todo.errors`).
- `app/controllers/todos_controller.rb:23-35` — `create` action; on failure it re-renders `:new` with `status: :unprocessable_content` at `todos_controller.rb:31`.
- `app/controllers/todos_controller.rb:74-76` — `todo_params` strong parameters (`params.expect(todo: [:description])`).

Confirmed each path/line exists. **Finding:** the form *renders* errors, but the model had **no validations**, so a blank description saved successfully and the error path never fired — a real rough edge (addressed in the Agent step below).

### Plan mode (design)

**Prompt:**
> "I want to change todo creation so that a todo must have a non-blank description: the model rejects blank descriptions and the existing form error block shows the message. Propose a plan as a numbered list of changes, including files to edit, new tests to add, and any migration. Do not write code."

**Plan Cursor returned:**
1. Add `validates :description, presence: true` to `app/models/todo.rb`.
2. Add a model test in `test/models/todo_test.rb` asserting invalid when blank, valid when present.
3. Add a controller test asserting `create` with a blank description does **not** increase `Todo.count` and re-renders `:new` with `422`.
4. Update `test/fixtures/todos.yml` if any fixture has a blank description.
5. Add a DB-level `null: false` migration on `description` for defense in depth.

**My edits to the plan:**
- **Cut step 5** (DB `null: false` migration). It's out of scope for a "must not be blank" rule, risks failing on existing rows, and a DB `NOT NULL` still allows `""`; the model validation is the right layer. Keeping migrations reversible/minimal per my rules.
- **Cut step 4** — the fixtures (`description: MyString`) are already non-blank, so no change needed.
- Kept steps 1–2 as the smallest valuable slice; deferred step 3 (controller-level) as a follow-up.

### Agent mode (execute the smallest slice)

**Step implemented:** plan step 1 + 2 (model validation + model test).

**Prompt:**
> "In `app/models/todo.rb` add `validates :description, presence: true`. In `test/models/todo_test.rb` add a Minitest test that a Todo is invalid with a blank description (error includes \"can't be blank\") and valid with a description. Run `bin/rails test test/models/todo_test.rb`. Don't touch anything else or add gems."

**Commit:** https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/commit/b3d4b08

### Bad → good prompt rewrite

**Bad prompt:**
> "fix the bug in todos"

**Good prompt:**
> 1. **Context:** `app/models/todo.rb`, `app/controllers/todos_controller.rb` (`create`, lines 23–35), the error partial `app/views/todos/_form.html.erb` (lines 2–12), and `test/models/todo_test.rb`.
> 2. **Task:** require a todo's `description` to be present.
> 3. **Expected vs. actual:** Expected — submitting the new-todo form with an empty description re-renders `new` with a "Description can't be blank" error and saves nothing. Actual — a Todo with `description = ""` saves successfully and shows as an empty row on the index, because the model has no validations.
> 4. **Constraints:** only edit the model and its test; no new gems; follow Minitest conventions; do not change controller behavior beyond what the validation triggers.
> 5. **Done when:** `bin/rails test test/models/todo_test.rb` passes a new test asserting blank descriptions are invalid and present ones are valid, and creating a todo with a blank description in the browser shows the error instead of an empty row.

---

## Part 4 — Turbo Streams feature

### Turbo Streams explanation (my own words)

A **Turbo Stream** is a fragment of HTML wrapped in `<turbo-stream>` elements that tells the page to perform a targeted DOM operation (replace, update, append, etc.) on a specific element, instead of returning a whole new page. The server signals this with the MIME type **`text/vnd.turbo-stream.html`**. The Hotwire-driven `<form>`/link automatically sends `Accept: text/vnd.turbo-stream.html`; the controller responds with `format.turbo_stream`, and Rails renders the matching view named `<action>.turbo_stream.erb` (e.g. `app/views/todos/toggle_priority.turbo_stream.erb`). Each `<turbo-stream action="replace" target="dom_id">` swaps just one element, so the rest of the page never re-renders and there's no full navigation.

**One thing the AI said that I verified:** the AI claimed there are exactly seven stream actions (`append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`) and that the response MIME type is `text/vnd.turbo-stream.html`. I checked the Turbo Handbook ("Streams" section) and the `turbo-rails` source (`Turbo::Streams::TagBuilder`), which confirm those seven actions, and I confirmed the MIME type live in DevTools (see below). The AI also correctly stated the matching view convention is `app/views/todos/toggle_priority.turbo_stream.erb`.

**Self-check answers:** MIME type = `text/vnd.turbo-stream.html`; the matching view for `toggle_priority` on `TodosController` lives at `app/views/todos/toggle_priority.turbo_stream.erb`.

**Existing Turbo Streams in the app before my change:** none.

### Browser (DevTools Network) verification

Clicking the toggle on `/todos` issued a `PATCH /todos/1/toggle_priority` request:
- **Request `Accept` header** included `text/vnd.turbo-stream.html`.
- **Response `Content-Type`** was `text/vnd.turbo-stream.html; charset=utf-8` (status `200`).
- Response body: `<turbo-stream action="replace" target="todo_1">…</turbo-stream>`.
- The page did **not** navigate / fully reload — only the toggled row's button changed (`☆ Normal` → `★ High priority`).

### Feature commits (≈3 small slices)

1. Migration + model attribute: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/commit/d19a0a0
2. Route + controller action: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/commit/dc6e368
3. Turbo Stream view + toggle button + test: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/commit/f025a92

### Pull request

PR (hw5 → main): https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/pull/1

---

## Submission checklist

- [x] GitHub Classroom hw5 repository / branch link (top of this doc)
- [x] Link to `.cursorignore`
- [x] Links to `AGENTS.md`, `.cursor/rules/rails-conventions.mdc`, `.cursor/rules/security.mdc`
- [x] Part 3: Ask-mode prompt/results, Plan-mode result + my edits, Agent-mode prompt + commit link, bad → good rewrite
- [x] Part 4: Turbo Streams explanation + what I verified against the handbook/source
- [x] Part 4 pull request URL with Story / Plan / Tests / Things I rejected: https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-rsmkhal/pull/1
