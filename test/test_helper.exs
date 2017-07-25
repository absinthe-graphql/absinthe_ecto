Mix.Task.run "ecto.drop", ["quiet", "-r", "Absinthe.Ecto.TestRepo"]
Mix.Task.run "ecto.create", ["quiet", "-r", "Absinthe.Ecto.TestRepo"]
Mix.Task.run "ecto.migrate", ["-r", "Absinthe.Ecto.TestRepo"]

Absinthe.Ecto.TestRepo.start_link
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Absinthe.Ecto.TestRepo, :manual)
