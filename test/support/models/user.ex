defmodule Absinthe.Ecto.User do
  use Ecto.Schema

  schema "users" do
    field :username, :string

    has_many :posts, Absinthe.Ecto.Post
  end
end
