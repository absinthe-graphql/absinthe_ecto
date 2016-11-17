defmodule Absinthe.Ecto do
  import Ecto.Query
  import Absinthe.Resolution.Helpers

  defmacro __using__([repo: repo]) do
    quote do
      import unquote(__MODULE__), only: [
        assoc: 1,
        ecto_batch: 3,
        ecto_batch: 4,
      ]
      @__absinthe_ecto_repo__ unquote(repo)
    end
  end

  defmacro assoc(association) do
    quote do
      unquote(__MODULE__).assoc(@__absinthe_ecto_repo__, unquote(association))
    end
  end

  defp default_callback(result) do
    {:ok, result}
  end

  def assoc(repo, association) do
    fn parent, _, _ ->
      case Map.get(parent, association) do
        %Ecto.Association.NotLoaded{} ->
          ecto_batch(repo, parent, association)
        val ->
          {:ok, val}
      end
    end
  end

  @doc """
  """
  def ecto_batch(repo, %model{} = parent, association, callback \\ &default_callback/1) do
    case model.__schema__(:association, association) do
      %Ecto.Association.BelongsTo{} = assoc ->
        build_batch(:perform_belongs_to, repo, parent, assoc, callback)
      %Ecto.Association.Has{cardinality: :many} = assoc ->
        build_batch(:perform_has_many, repo, parent, assoc, callback)
    end
  end

  @doc """
  """
  def build_batch(batch_fun, repo, parent, assoc, callback) do
    id = Map.fetch!(parent, assoc.owner_key)

    meta = {repo, assoc.queryable, assoc.related_key, self()}

    batch({__MODULE__, batch_fun, meta}, id, fn results ->
      results
      |> Map.get(id)
      |> callback.()
    end)
  end

  @doc false
  def perform_has_many({repo, model, foreign_key, caller}, ids) do
    model
    |> where([m], field(m, ^foreign_key) in ^ids)
    |> repo.all(caller: caller)
    |> Enum.group_by(&Map.fetch!(&1, foreign_key))
  end

  @doc false
  def perform_belongs_to({repo, model, foreign_key, caller}, model_ids) do
    model
    |> where([m], field(m, ^foreign_key) in ^model_ids)
    |> select([m], {m.id, m})
    |> repo.all(caller: caller)
    |> Map.new
  end
end
