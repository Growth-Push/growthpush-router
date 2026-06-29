defmodule GrowthPushRouter.MixProject do
  use Mix.Project

  def project do
    [
      app: :growthpush_router,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {GrowthPushRouter.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test,
        "precommit.full": :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix / runtime
      {:phoenix, "~> 1.8.8"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.2.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Assets
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Data / HTTP
      {:req, "~> 0.5"},

      # Auth / mail
      {:bcrypt_elixir, "~> 3.0"},
      {:swoosh, "~> 1.18"},
      {:finch, "~> 0.23"},

      # Jobs
      {:oban, "~> 2.19"},

      # Security / observability
      {:hammer, "~> 6.2"},

      # Dev / test
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:faker, "~> 0.18", only: [:dev, :test]},
      {:mox, "~> 1.2", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind growthpush_router", "esbuild growthpush_router"],
      "assets.deploy": [
        "tailwind growthpush_router --minify",
        "esbuild growthpush_router --minify",
        "phx.digest"
      ],
      precommit: [
        "format",
        "compile --warnings-as-errors",
        "test"
      ],
      "precommit.full": [
        "precommit",
        "deps.unlock --unused",
        "dialyzer",
        "credo --strict",
        "sobelow --config .sobelow-conf --exit",
        "deps.audit",
        "docs"
      ]
    ]
  end
end
