This folder contains repository-local Git hooks.

## Install instructions
- Run the bash script: `scripts/setup-hooks` from the repository root

After running the setup script, Git will execute `.githooks/pre-commit` before commits.

## Notes
- The pre-commit hook runs the following commands and will fail the commit if any fail:
  - `mix format --check-formatted`
  - `mix credo --strict`
  - `mix compile --warnings-as-errors`
  - `mix dialyzer`
- Ensure Elixir, Erlang/OTP and Dialyzer are installed and the project dependencies are fetched locally.
- Dialyzer can be slow or require PLT setup the first time; consider running it locally once before committing.
