defmodule Absinthe.Ecto.TestRepo do
  use Ecto.Repo, otp_app: :absinthe_ecto

  def reload(%{__struct__: model, id: id}) do
    __MODULE__.get(model, id)
  end
end
