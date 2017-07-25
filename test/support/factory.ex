defmodule Absinthe.Ecto.Factory do
  use ExMachina.Ecto, repo: Absinthe.Ecto.TestRepo

  def user_factory do
    %Absinthe.Ecto.User{
      username: "username",
    }
  end

  def post_factory do
    %Absinthe.Ecto.Post{
      user: build(:user),
    }
  end
end
