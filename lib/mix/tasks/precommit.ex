defmodule Mix.Tasks.Precommit do
  @shortdoc "Run format, compile (warnings-as-errors), and tests"
  @moduledoc "Pre-commit checks: formatting, compilation with warnings-as-errors, and tests."
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    steps = [
      {"Formatting", "format", ["--check-formatted"]},
      {"Compiling", "compile", ["--warnings-as-errors"]},
      {"Testing", "test", []}
    ]

    Enum.each(steps, fn {label, task, args} ->
      Mix.shell().info("==> #{label}...")
      Mix.Task.rerun(task, args)
    end)

    Mix.shell().info("All checks passed.")
  end
end
