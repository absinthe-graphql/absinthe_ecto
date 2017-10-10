# Absinthe.Ecto

[![Hex pm](http://img.shields.io/hexpm/v/absinthe_ecto.svg?style=flat)](https://hex.pm/packages/absinthe_ecto)[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Provides some helper functions for easy batching of Ecto assocations

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
  field :name, :string
  field :body, :string
end
```

Now, queries which get the author or comments of many posts will result in
just 1 call to the database for each!

The `assoc` macro just builds a resolution function which calls `ecto_batch/4`.

See the `ecto_batch/4` function for how to do this from within a regular
resolution function.

## License

See [LICENSE.md](./LICENSE.md).
