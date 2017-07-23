defmodule Absinthe.Ecto.Post do
  use Ecto.Schema

  schema "posts" do
    belongs_to :user, Absinthe.Ecto.User
  end
end
