defmodule Absinthe.Ecto do
  import Absinthe.Resolution.Helpers
  import Ecto.Query

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
        assoc: 2,
        ecto_batch: 3,
        ecto_batch: 4,
      ]
      @__absinthe_ecto_repo__ unquote(repo)
    end
  end

  @doc false
  def __check_absinthe_ecto_repo__(nil), do: raise """
  You must `use Absinthe.Ecto, repo: MyApp.Repo` with your application's repo.
  """

  @doc false
  def __check_absinthe_ecto_repo__(_), do: nil

  @doc """
  Example:

  ```elixir
  field :author, :user, resolve: assoc(:author)
  ```
  """
  defmacro assoc(association) do
    quote do
      # silent `warning: this check/guard will always yield the same result`
      unquote(__MODULE__).__check_absinthe_ecto_repo__(@__absinthe_ecto_repo__)
      unquote(__MODULE__).assoc(@__absinthe_ecto_repo__, unquote(association), nil)
    end
  end

  @doc """
  Example:

  ```elixir
  field :posts, list_of(:post) do
    resolve assoc(:posts, fn posts_query, _args, _context ->
      posts_query |> order_by(asc: :name)
    end)
  end
  ```
  """
  defmacro assoc(association, query_fun) do
    quote do
      # silent `warning: this check/guard will always yield the same result`
      unquote(__MODULE__).__check_absinthe_ecto_repo__(@__absinthe_ecto_repo__)
      unquote(__MODULE__).assoc(@__absinthe_ecto_repo__, unquote(association), unquote(query_fun))
    end
  end

  defp default_callback(result) do
    {:ok, result}
  end

  @doc """
  Generally you would use the `assoc/1` macro.

  However, this can be useful if you need to specify an ecto repo.

  ```elixir
  field :author, :user, resolve: assoc(MyApp.Repo, :author)
  ```
  """
  def assoc(repo, association, query_fun, callback \\ &default_callback/1) do
    fn parent, args, %{context: ctx} ->
      case Map.get(parent, association) do
        %Ecto.Association.NotLoaded{} ->
          if query_fun != nil do
            ecto_batch(repo, parent, {association, fn query -> query_fun.(query, args, ctx) end}, callback)
          else
            ecto_batch(repo, parent, association, callback)
          end
        val ->
          {:ok, val}
      end
    end
  end

  @doc """
  This function lets you batch load an item from within a normal resolution function.

  It also supports a callback which is run after the item is loaded. For belongs
  to associations this may be nil.

  ## Example

  ```elixir
  resolve fn post, _, _ ->
    MyApp.Repo |> ecto_batch(post, :author, fn author ->
      # you can do something with the author after its loaded here.
      # note that it may be nil.
      {:ok, author}
    end)
  end
  ```
  """
  def ecto_batch(repo, %model{} = parent, association, callback \\ &default_callback/1) do
    {assoc_field, query_fun} = normalize(association)
    assoc = model.__schema__(:association, assoc_field)

    %{owner: owner,
      owner_key: owner_key,
      field: field } = assoc

    id = Map.fetch!(parent, owner_key)

    query = resolve_query(query_fun, assoc, parent)
    meta = {repo, owner, owner_key, field, query, self()}

    batch({__MODULE__, :perform_batch, meta}, id, fn results ->
      results
      |> Map.get(id)
      |> callback.()
    end)
  end

  defp normalize(field) when is_atom(field), do: {field, nil}
  defp normalize({field, query_fun}), do: {field, query_fun}

  # Query is resolved with `Repo.preload(association_name: query)`, so it must
  # return the association type.
  defp resolve_query(query_fun, %{queryable: queryable}, _) when is_function(query_fun), do: query_fun.(from(queryable))
  defp resolve_query(query_fun, %{field: field}, parent) when is_function(query_fun), do: query_fun.(Ecto.assoc(parent, field))
  defp resolve_query(_, _, _), do: nil

  @doc false
  # this has to be public because it gets called from the absinthe batcher
  def perform_batch({repo, owner, owner_key, field, query, caller}, ids) do
    unique_ids = ids |> MapSet.new |> MapSet.to_list
    preload = if query != nil, do: [{field, query}], else: field

    unique_ids
    |> Enum.map(&Map.put(struct(owner), owner_key, &1))
    |> repo.preload(preload, caller: caller)
    |> Enum.map(&{Map.get(&1, owner_key), Map.get(&1, field)})
    |> Map.new
  end
end
