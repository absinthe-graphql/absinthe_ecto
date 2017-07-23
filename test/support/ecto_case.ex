defmodule Absinthe.Ecto.EctoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Absinthe.Ecto.Factory
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Absinthe.Ecto.TestRepo)
  end
end
