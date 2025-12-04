# Elixir Code Style Guide for FrameCore

This project follows idiomatic Elixir conventions with emphasis on type safety and documentation.

## Core Principles

1. **Type Safety**: Use `@spec` and `@type` annotations on all public functions
2. **Documentation**: Use `@moduledoc` and `@doc` on all public modules and functions
3. **Explicit Implementations**: Use `@impl true` for all behavior callbacks
4. **Dependency Injection**: Use behaviors and structs for testability
5. **Compile-Time Guarantees**: Prefer compile-time errors over runtime errors

## Module Structure

Order module contents consistently:

```elixir
defmodule MyModule do
  @moduledoc """
  Clear description of what this module does.
  """

  # Behaviors and use statements
  use GenServer
  @behaviour MyBehaviour

  # Module attributes and types
  @type my_type :: term()
  @default_value 42

  # Nested modules (like Config)
  defmodule Config do
    # ...
  end

  ## Client API (comment section)

  @spec public_function(arg :: type()) :: return_type()
  def public_function(arg), do: ...

  ## Server Callbacks (for GenServers)

  @impl true
  @spec init(term()) :: {:ok, state()}
  def init(_), do: ...

  ## Private Functions

  defp private_function, do: ...
end
```

## Type Specifications

### Always add @spec to public functions:
```elixir
@spec get() :: String.t()
def get, do: GenServer.call(__MODULE__, :get)

@spec start_link(Config.t()) :: GenServer.on_start()
def start_link(%Config{} = config) do
  GenServer.start_link(__MODULE__, config, name: __MODULE__)
end
```

### Define custom types for clarity:
```elixir
@type state :: %{
  count: non_neg_integer(),
  status: :active | :paused
}

@type error :: {:error, atom() | String.t()}
```

### Use @type for module state:
```elixir
defmodule MyGenServer do
  @type state :: map()
  
  @impl true
  @spec init(term()) :: {:ok, state()}
  def init(_), do: {:ok, %{}}
end
```

## Configuration Structs

Use structs for configuration with `@enforce_keys`:

```elixir
defmodule MyModule.Config do
  @moduledoc """
  Configuration for MyModule.
  """
  
  @enforce_keys [:required_field]
  defstruct [:required_field, optional_field: :default_value]
  
  @type t :: %__MODULE__{
    required_field: String.t(),
    optional_field: atom()
  }
end
```

## Behaviors and Dependency Injection

### Define behaviors for mockable dependencies:

```elixir
defmodule MyApp.HttpClient do
  @moduledoc """
  Behavior for HTTP client operations.
  """
  
  @callback get(url :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback post(url :: String.t(), body :: term()) :: {:ok, term()} | {:error, term()}
end
```

### Implement the real version:

```elixir
defmodule MyApp.HttpClient.Real do
  @moduledoc """
  Real HTTP client implementation using HTTPoison.
  """
  
  @behaviour MyApp.HttpClient
  
  @impl true
  def get(url), do: HTTPoison.get(url)
  
  @impl true
  def post(url, body), do: HTTPoison.post(url, body)
end
```

### Inject as a dependency:

```elixir
defmodule MyService do
  defmodule Config do
    @enforce_keys [:http_client]
    defstruct [:http_client]
    
    @type t :: %__MODULE__{
      http_client: module()
    }
  end
  
  def fetch_data(%Config{http_client: client}) do
    client.get("https://api.example.com/data")
  end
end
```

## GenServer Callbacks

Always use `@impl true`:

```elixir
@impl true
@spec init(Config.t()) :: {:ok, state()}
def init(%Config{} = config), do: {:ok, initial_state(config)}

@impl true
@spec handle_call(term(), GenServer.from(), state()) :: 
  {:reply, term(), state()}
def handle_call(:get, _from, state), do: {:reply, state, state}

@impl true
@spec handle_cast(term(), state()) :: {:noreply, state()}
def handle_cast(:reset, _state), do: {:noreply, initial_state()}
```

## Documentation

### Module documentation:
```elixir
@moduledoc """
One-line summary.

More detailed explanation if needed. Can include:
- Examples
- Usage patterns
- Important notes
"""
```

### Function documentation:
```elixir
@doc """
Brief description of what the function does.

## Examples

    iex> MyModule.add(1, 2)
    3
"""
@spec add(integer(), integer()) :: integer()
def add(a, b), do: a + b
```

## Testing

### Use Mox for mocking:

```elixir
# test/test_helper.exs
Mox.defmock(MyApp.HttpClientMock, for: MyApp.HttpClient)

# In tests
setup :set_mox_global
setup :verify_on_exit!

test "fetches data" do
  expect(MyApp.HttpClientMock, :get, fn _url ->
    {:ok, %{data: "test"}}
  end)
  
  config = %MyService.Config{http_client: MyApp.HttpClientMock}
  assert {:ok, _} = MyService.fetch_data(config)
end
```

## Tooling

### Credo (Static Analysis)
Run before committing:
```bash
mix credo --strict
```

### Dialyzer (Type Checking)
Run periodically:
```bash
mix dialyzer
```

### Formatting
Auto-format on save (already configured in .formatter.exs):
```bash
mix format
```

## Naming Conventions

- **Modules**: `PascalCase`
- **Functions/variables**: `snake_case`
- **Atoms**: `:snake_case`
- **Constants**: `@upper_snake_case` (module attributes)
- **GenServer names**: Match module name or use descriptive atom

## Error Handling

Prefer explicit error tuples over exceptions:

```elixir
# Good
@spec fetch_user(id :: integer()) :: {:ok, User.t()} | {:error, :not_found}
def fetch_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end

# Exceptions only for truly exceptional cases
def fetch_user!(id) do
  case fetch_user(id) do
    {:ok, user} -> user
    {:error, reason} -> raise "Failed to fetch user: #{reason}"
  end
end
```

## Pattern Matching

Use pattern matching for clarity:

```elixir
# Good - explicit patterns
def handle_response({:ok, %{status: 200, body: body}}), do: process(body)
def handle_response({:ok, %{status: status}}), do: {:error, status}
def handle_response({:error, reason}), do: {:error, reason}

# Less clear - nested case statements
def handle_response(response) do
  case response do
    {:ok, result} ->
      case result.status do
        200 -> process(result.body)
        status -> {:error, status}
      end
    {:error, reason} -> {:error, reason}
  end
end
```

## Resources

- [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- [Credo Documentation](https://hexdocs.pm/credo)
- [Dialyzer Documentation](https://hexdocs.pm/dialyxir)
- [Writing Typespecs](https://hexdocs.pm/elixir/typespecs.html)
