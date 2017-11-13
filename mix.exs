defmodule Absinthe.Ecto.Mixfile do
  use Mix.Project

  @version "0.1.3"

  def project do
    [app: :absinthe_ecto,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     elixirc_paths: elixirc_paths(Mix.env),
     package: package(),
     source_url: "https://github.com/absinthe-graphql/absinthe_ecto",
     docs: [source_ref: "v#{@version}", main: "Absinthe.Ecto"],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :absinthe, :ecto]]
  end

  defp package do
    [description: "GraphQL helpers for Absinthe",
     files: ["lib", "priv", "mix.exs", "README*"],
     maintainers: ["Bruce Williams", "Ben Wilson"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/absinthe-graphql/absinthe_ecto"}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:absinthe, "~> 1.3.0 or ~> 1.4.0"},
      {:ecto, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: [:dev]},
      {:postgrex, ">= 0.13.0", only: [:test]},
      {:ex_machina, ">= 2.0.0", only: [:test]},
    ]
  end

  defp elixirc_paths(:test), do: elixirc_paths() ++ ["test/support"]
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths(), do: ["lib"]
end
