defmodule Absinthe.Ecto do
  import Ecto.Query
  import Absinthe.Resolution.Helpers

  @moduledoc """
  Provides some helper functions for easy batching of ecto assocations

  These functions all make use of the batch plugin found in Absinthe, they're
  merely just some helpful ways to use this plugin in the context of simple ecto
  associations.

  ## Basic Usage
  First specify the repo you're going to use:

  ```elixir
  use Absinthe.Ecto, repo: MyApp.Repo
  ```

  Then, supposing you have some ecto associations as in this example schema:
  ```elixir
  defmodule MyApp.Post do
    use Ecto.Schema

    schema "posts" do
      belongs_to :author, MyApp.User
      has_many :comments, MyApp.Comment
      field :name, :string
      field :body, :string
    end
  end
  ```

  Your graphql post object might look like:
  ```elixir
  object :post do
    field :author, :user, resolve: assoc(:author)
    field :comments, list_of(:comment), resolve: assoc(:comments)
    field :title, :string
    field :body, :string
  end
  ```

  Now, queries which get the author or comments of many posts will result in
  just 1 call to the database for each!

  The `assoc` macro just builds a resolution function which calls `ecto_batch/4`.

  See the `ecto_batch/4` function for how to do this from within a regular
  resolution function.
  """

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

  @doc """
  Example:
  ```elixir
  field :author, :user, resolve: assoc(:author)
  ```
  """
  defmacro assoc(association) do
    quote do
      unless @__absinthe_ecto_repo__, do: raise """
      You must `use Absinthe.Ecto, repo: MyApp.Repo` with your application's repo.
      """
      unquote(__MODULE__).assoc(@__absinthe_ecto_repo__, unquote(association))
    end
  end

  defp default_callback(result) do
    {:ok, result}
  end

  @doc """
  Generally you would use the `assoc/1` macro.

  However, this can be useful if you need to specify an ecto repo.
  
  This accepts either an atom representing an association directly on the parent,
  or a list of atoms representing a path to the association with the parent
  as the root node.
  
  If the child of the parent the association depends on does not exist, or is not
  transversable, it will return `nil`.

  ```elixir
  # Association specified directly on the parent (ie. parent.author)
  field :author, :user, resolve: assoc(MyApp.Repo, :author)
  
  # Association specified on a child of the parent (ie. parent.user.author)
  field :author, :user, resolve: assoc(MyApp.Repo, [:user, :author])
  ```
  """
  def assoc(repo, association) do
    fn parent, _, _ ->
      case association do
        [] -> raise "Association path can not be empty"
        [_|_] -> walk_assoc(parent, repo, association)
        _ -> assoc_node(parent, repo, association)    
      end
    end
  end

  defp assoc_node(parent, repo, association) do
    case Map.get(parent, association) do
      %Ecto.Association.NotLoaded{} ->
        ecto_batch(repo, parent, association)
      val ->
        {:ok, val}
    end
  end

  defp walk_assoc(parent, repo, [association]) do
    assoc_node(parent, repo, association)
  end

  defp walk_assoc(%{} = parent, repo, [node|path]) do
    case Map.get(parent, node) do
      nil -> {:ok, nil}
      val -> walk_assoc(val, repo, path)
    end
  end

  defp walk_assoc(_parent, _repo, _path), do: {:ok, nil}

  @doc """
  This function lets you batch load an item from within a normal resolution function.

  It also supports a callback which is run after the item is loaded. For belongs
  to associations this may be nil.

  ## Example
  resolve fn post, _, _ ->
    MyApp.Repo |> ecto_batch(post, :author, fn author ->
      # you can do something with the author after its loaded here.
      # note that it may be nil.
      {:ok, author}
    end)
  end
  """
  def ecto_batch(repo, %model{} = parent, association, callback \\ &default_callback/1) do
    case model.__schema__(:association, association) do
      %Ecto.Association.BelongsTo{} = assoc ->
        build_batch(:perform_belongs_to, repo, parent, assoc, callback)
      %Ecto.Association.Has{cardinality: :many} = assoc ->
        build_batch(:perform_has_many, repo, parent, assoc, callback)
    end
  end

  defp build_batch(batch_fun, repo, parent, assoc, callback) do
    id = Map.fetch!(parent, assoc.owner_key)

    meta = {repo, assoc.queryable, assoc.related_key, self()}

    batch({__MODULE__, batch_fun, meta}, id, fn results ->
      results
      |> Map.get(id, default_result(batch_fun))
      |> callback.()
    end)
  end

  defp default_result(:perform_belongs_to), do: nil
  defp default_result(:perform_has_many), do: []

  @doc false
  # this has to be public because it gets called from the absinthe batcher
  def perform_has_many({repo, model, foreign_key, caller}, ids) do
    model
    |> where([m], field(m, ^foreign_key) in ^ids)
    |> repo.all(caller: caller)
    |> Enum.group_by(&Map.fetch!(&1, foreign_key))
  end

  @doc false
  # this has to be public because it gets called from the absinthe batcher
  def perform_belongs_to({repo, model, foreign_key, caller}, model_ids) do
    model
    |> where([m], field(m, ^foreign_key) in ^model_ids)
    |> select([m], {m.id, m})
    |> repo.all(caller: caller)
    |> Map.new
  end
end
