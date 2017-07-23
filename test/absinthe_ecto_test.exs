defmodule Absinthe.EctoTest do
  use Absinthe.Ecto.EctoCase
  import Absinthe.Ecto
  doctest Absinthe.Ecto

  describe "ecto_batch/3" do
    test "it returns batch middleware that performs a valid Ecto query" do
      user = insert(:user)
      post = insert(:post, user: user) |> Absinthe.Ecto.TestRepo.reload
      user_id = user.id

      {
        :middleware,
        Absinthe.Middleware.Batch,
        {
          {
            Absinthe.Ecto,
            :perform_batch,
            batch
          },
          ^user_id,
          _fun,
          []
        }
      } = ecto_batch(Absinthe.Ecto.TestRepo, user, :posts)

      batch_result = perform_batch(batch, [user_id])

      assert batch_result == %{
        user_id => [post]
      }
    end
  end
end
