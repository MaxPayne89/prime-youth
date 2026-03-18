# Idiomatic Elixir Examples

Code examples for each pattern in `SKILL.md`.

---

## Pattern 1: Pattern Matching - Multi-Clause Functions

### Basic Pattern Matching in Function Clauses

```elixir
# Instead of conditionals inside a single function
defmodule OrderProcessor do
  # Bad: conditional logic inside
  def process_bad(order) do
    if order.status == :pending do
      # handle pending
    else
      if order.status == :paid do
        # handle paid
      end
    end
  end

  # Good: pattern matching on struct field
  def process(%Order{status: :pending} = order) do
    {:ok, %{order | status: :processing}}
  end

  def process(%Order{status: :paid} = order) do
    {:ok, ship_order(order)}
  end

  def process(%Order{status: :cancelled}) do
    {:error, :already_cancelled}
  end

  def process(%Order{status: status}) do
    {:error, {:invalid_status, status}}
  end
end
```

### Guards for Additional Constraints

```elixir
defmodule Pricing do
  def calculate_discount(price, quantity) when quantity >= 100 do
    price * 0.80  # 20% bulk discount
  end

  def calculate_discount(price, quantity) when quantity >= 50 do
    price * 0.90  # 10% discount
  end

  def calculate_discount(price, _quantity) do
    price  # No discount
  end
end
```

### Destructuring in Function Arguments

```elixir
defmodule UserNotification do
  def send(%User{email: email, preferences: %{notifications: true}}) do
    Mailer.send(email, "You have updates!")
  end

  def send(%User{preferences: %{notifications: false}}) do
    :skipped  # User opted out
  end
end
```

---

## Pattern 2: Pipe Operator - Data Transformation Pipelines

### Basic Pipeline

```elixir
# Bad: nested function calls
result = String.trim(String.downcase(String.replace(input, "-", "_")))

# Good: pipe operator
result =
  input
  |> String.replace("-", "_")
  |> String.downcase()
  |> String.trim()
```

### Domain Transformation Pipeline

```elixir
defmodule OrderService do
  def create_order(params, user) do
    params
    |> build_order(user)
    |> validate_inventory()
    |> calculate_totals()
    |> apply_discounts(user)
    |> persist()
  end

  defp build_order(params, user) do
    %Order{
      user_id: user.id,
      items: params["items"],
      status: :draft
    }
  end

  defp validate_inventory(order) do
    # Returns order or raises on invalid inventory
    order
  end

  defp calculate_totals(order) do
    total = Enum.reduce(order.items, 0, &(&1.price * &1.quantity + &2))
    %{order | total: total}
  end

  defp apply_discounts(order, user) do
    discount = Discounts.for_user(user)
    %{order | total: order.total * (1 - discount)}
  end

  defp persist(order) do
    Repo.insert(order)
  end
end
```

### Breaking Long Pipelines

```elixir
defmodule ReportGenerator do
  def generate(raw_data) do
    raw_data
    |> parse_and_validate()
    |> enrich_with_metadata()
    |> format_output()
  end

  defp parse_and_validate(data) do
    data
    |> JSON.decode!()
    |> Map.get("records")
    |> Enum.filter(&valid_record?/1)
  end

  defp enrich_with_metadata(records) do
    records
    |> Enum.map(&fetch_user_data/1)
    |> Enum.map(&calculate_metrics/1)
  end

  defp format_output(records) do
    records
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.map(&to_report_row/1)
  end
end
```

---

## Pattern 3: With Statement - Railway-Oriented Error Handling

### Basic With Statement

```elixir
defmodule UserRegistration do
  def register(params) do
    with {:ok, validated} <- validate_params(params),
         {:ok, user} <- create_user(validated),
         {:ok, _email} <- send_welcome_email(user) do
      {:ok, user}
    else
      {:error, :invalid_email} -> {:error, "Please provide a valid email"}
      {:error, :email_taken} -> {:error, "Email already registered"}
      {:error, :email_failed} -> {:error, "Registration complete but email failed"}
      error -> error
    end
  end

  defp validate_params(%{"email" => email}) when is_binary(email) do
    if String.contains?(email, "@") do
      {:ok, %{email: email}}
    else
      {:error, :invalid_email}
    end
  end

  defp validate_params(_), do: {:error, :invalid_email}

  defp create_user(attrs) do
    case Repo.get_by(User, email: attrs.email) do
      nil -> Repo.insert(%User{email: attrs.email})
      _exists -> {:error, :email_taken}
    end
  end

  defp send_welcome_email(user) do
    case Mailer.deliver(user.email, "Welcome!") do
      :ok -> {:ok, :sent}
      _ -> {:error, :email_failed}
    end
  end
end
```

### Tagged With for Error Source Tracking

```elixir
defmodule PaymentProcessor do
  def process_payment(order, payment_info) do
    with {:validate, {:ok, order}} <- {:validate, validate_order(order)},
         {:authorize, {:ok, auth}} <- {:authorize, authorize_payment(payment_info)},
         {:capture, {:ok, capture}} <- {:capture, capture_funds(auth, order.total)},
         {:update, {:ok, order}} <- {:update, mark_order_paid(order, capture)} do
      {:ok, order}
    else
      {:validate, {:error, reason}} ->
        {:error, {:validation_failed, reason}}

      {:authorize, {:error, reason}} ->
        {:error, {:authorization_failed, reason}}

      {:capture, {:error, reason}} ->
        void_authorization()
        {:error, {:capture_failed, reason}}

      {:update, {:error, reason}} ->
        Logger.error("Payment captured but order update failed: #{inspect(reason)}")
        {:error, {:update_failed, reason}}
    end
  end
end
```

---

## Pattern 4: Structs - Domain Entity Modeling

### Basic Struct with Enforced Keys

```elixir
defmodule Money do
  @enforce_keys [:amount, :currency]
  defstruct [:amount, :currency]

  @type t :: %__MODULE__{
    amount: integer(),
    currency: atom()
  }

  def new(amount, currency) when is_integer(amount) and is_atom(currency) do
    %__MODULE__{amount: amount, currency: currency}
  end

  def add(%__MODULE__{currency: c} = a, %__MODULE__{currency: c} = b) do
    %{a | amount: a.amount + b.amount}
  end

  def add(_, _), do: raise ArgumentError, "Cannot add different currencies"
end
```

### Entity with Identity

```elixir
defmodule User do
  @enforce_keys [:id, :email]
  defstruct [:id, :email, :name, :created_at, status: :active]

  @type t :: %__MODULE__{
    id: binary(),
    email: String.t(),
    name: String.t() | nil,
    status: :active | :suspended | :deleted,
    created_at: DateTime.t() | nil
  }

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id] || generate_id(),
      email: attrs.email,
      name: attrs[:name],
      created_at: DateTime.utc_now()
    }
  end

  defp generate_id, do: Ecto.UUID.generate()
end
```

### Value Object (No Identity)

```elixir
defmodule Address do
  @enforce_keys [:street, :city, :country]
  defstruct [:street, :city, :state, :country, :postal_code]

  @type t :: %__MODULE__{
    street: String.t(),
    city: String.t(),
    state: String.t() | nil,
    country: String.t(),
    postal_code: String.t() | nil
  }

  # Value objects are equal if all attributes match
  # (Elixir structs do this by default)
end
```

---

## Pattern 5: Protocols - Polymorphism via Contracts

### Defining and Implementing a Protocol

```elixir
defprotocol Priceable do
  @doc "Returns the price in cents"
  @spec price(t) :: integer()
  def price(item)
end

defmodule Product do
  defstruct [:name, :base_price]
end

defmodule Subscription do
  defstruct [:plan, :monthly_rate, :months]
end

defmodule ServiceFee do
  defstruct [:description, :amount]
end

defimpl Priceable, for: Product do
  def price(%Product{base_price: p}), do: p
end

defimpl Priceable, for: Subscription do
  def price(%Subscription{monthly_rate: rate, months: m}), do: rate * m
end

defimpl Priceable, for: ServiceFee do
  def price(%ServiceFee{amount: a}), do: a
end

# Usage
defmodule Cart do
  def total(items) do
    Enum.sum_by(items, &Priceable.price/1)
  end
end
```

### Protocol for Serialization

```elixir
defprotocol Serializable do
  @spec to_map(t) :: map()
  def to_map(entity)
end

defimpl Serializable, for: User do
  def to_map(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      status: Atom.to_string(user.status)
    }
  end
end

defimpl Serializable, for: Order do
  def to_map(%Order{} = order) do
    %{
      id: order.id,
      total: order.total,
      items: Enum.map(order.items, &Serializable.to_map/1)
    }
  end
end
```

---

## Pattern 6: Behaviours - Callback Contracts for Modules

### Defining a Behaviour

```elixir
defmodule PaymentGateway do
  @callback authorize(amount :: integer(), card_token :: String.t()) ::
    {:ok, authorization_id :: String.t()} | {:error, reason :: atom()}

  @callback capture(authorization_id :: String.t(), amount :: integer()) ::
    {:ok, capture_id :: String.t()} | {:error, reason :: atom()}

  @callback refund(capture_id :: String.t(), amount :: integer()) ::
    {:ok, refund_id :: String.t()} | {:error, reason :: atom()}
end
```

### Implementing a Behaviour

```elixir
defmodule StripeGateway do
  @behaviour PaymentGateway

  @impl PaymentGateway
  def authorize(amount, card_token) do
    case Stripe.PaymentIntent.create(%{amount: amount, source: card_token}) do
      {:ok, intent} -> {:ok, intent.id}
      {:error, error} -> {:error, error.code}
    end
  end

  @impl PaymentGateway
  def capture(authorization_id, amount) do
    case Stripe.PaymentIntent.capture(authorization_id, %{amount: amount}) do
      {:ok, intent} -> {:ok, intent.id}
      {:error, error} -> {:error, error.code}
    end
  end

  @impl PaymentGateway
  def refund(capture_id, amount) do
    case Stripe.Refund.create(%{payment_intent: capture_id, amount: amount}) do
      {:ok, refund} -> {:ok, refund.id}
      {:error, error} -> {:error, error.code}
    end
  end
end

defmodule MockGateway do
  @behaviour PaymentGateway

  @impl PaymentGateway
  def authorize(_amount, _token), do: {:ok, "mock_auth_#{System.unique_integer()}"}

  @impl PaymentGateway
  def capture(_auth_id, _amount), do: {:ok, "mock_cap_#{System.unique_integer()}"}

  @impl PaymentGateway
  def refund(_cap_id, _amount), do: {:ok, "mock_ref_#{System.unique_integer()}"}
end
```

### Using Behaviours with Configuration

```elixir
defmodule Payments do
  def gateway do
    Application.get_env(:my_app, :payment_gateway, StripeGateway)
  end

  def charge(amount, card_token) do
    with {:ok, auth_id} <- gateway().authorize(amount, card_token),
         {:ok, capture_id} <- gateway().capture(auth_id, amount) do
      {:ok, capture_id}
    end
  end
end
```

---

## Pattern 7: Bounded Contexts - Phoenix Contexts

### Context Module Structure

```elixir
defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context handles user management,
  authentication, and authorization.
  """

  alias MyApp.Accounts.{User, Credential}
  alias MyApp.Repo

  # Public API - these are the only functions other contexts should call

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(email, password) do
    with user when not is_nil(user) <- get_user_by_email(email),
         true <- Credential.verify_password(user.credential, password) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  # Internal functions - not exposed
  defp hash_password(password) do
    Bcrypt.hash_pwd_salt(password)
  end
end
```

### Separate Context for Orders

```elixir
defmodule MyApp.Sales do
  @moduledoc """
  The Sales context handles orders, cart management,
  and checkout processes.
  """

  alias MyApp.Sales.{Order, LineItem, Cart}
  alias MyApp.Repo

  # Note: We don't directly access Accounts schemas
  # We only know about user_id, not the User struct

  def create_order(user_id, cart_items) do
    %Order{}
    |> Order.changeset(%{user_id: user_id, status: :pending})
    |> Ecto.Changeset.put_assoc(:line_items, build_line_items(cart_items))
    |> Repo.insert()
  end

  def get_orders_for_user(user_id) do
    Order
    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  defp build_line_items(cart_items) do
    Enum.map(cart_items, fn item ->
      %LineItem{product_id: item.product_id, quantity: item.quantity, price: item.price}
    end)
  end
end
```

---

## Pattern 8: Aggregates with Structs - Root Entities

### Aggregate Root with Nested Value Objects

```elixir
defmodule MyApp.Sales.Order do
  @enforce_keys [:id, :user_id, :status]
  defstruct [
    :id,
    :user_id,
    :status,
    :shipping_address,
    :billing_address,
    line_items: [],
    total: 0
  ]

  alias MyApp.Sales.{LineItem, Address}

  # All modifications go through the aggregate root

  def new(user_id) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      status: :draft,
      line_items: []
    }
  end

  def add_item(%__MODULE__{status: :draft} = order, product, quantity) do
    item = LineItem.new(product, quantity)
    items = order.line_items ++ [item]
    %{order | line_items: items, total: calculate_total(items)}
  end

  def add_item(%__MODULE__{}, _, _) do
    {:error, :order_not_modifiable}
  end

  def set_shipping_address(%__MODULE__{} = order, address_attrs) do
    address = struct!(Address, address_attrs)
    %{order | shipping_address: address}
  end

  def submit(%__MODULE__{status: :draft, line_items: items} = order)
      when length(items) > 0 do
    {:ok, %{order | status: :submitted}}
  end

  def submit(%__MODULE__{status: :draft, line_items: []}) do
    {:error, :empty_order}
  end

  def submit(%__MODULE__{}) do
    {:error, :already_submitted}
  end

  defp calculate_total(items) do
    Enum.sum_by(items, fn item -> item.price * item.quantity end)
  end
end
```

### Nested Value Object

```elixir
defmodule MyApp.Sales.LineItem do
  @enforce_keys [:product_id, :name, :price, :quantity]
  defstruct [:product_id, :name, :price, :quantity]

  def new(product, quantity) do
    %__MODULE__{
      product_id: product.id,
      name: product.name,
      price: product.price,
      quantity: quantity
    }
  end

  def subtotal(%__MODULE__{price: p, quantity: q}), do: p * q
end
```

---

## Pattern 9: Changesets - Domain Validation

### Basic Changeset

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :status, Ecto.Enum, values: [:active, :suspended], default: :active

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_length(:password, min: 8)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
```

### Context-Specific Changesets

```elixir
defmodule MyApp.Accounts.User do
  # ... schema definition ...

  # For registration - requires password
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  # For profile updates - no password change
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_length(:name, max: 100)
  end

  # For admin actions
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :status])
    |> validate_required([:email])
    |> validate_inclusion(:status, [:active, :suspended])
  end
end
```

---

## Pattern 10: Functional Core, Imperative Shell

### Pure Domain Logic (Core)

```elixir
defmodule MyApp.Pricing.Calculator do
  @moduledoc """
  Pure functions for price calculations.
  No side effects, no database calls, fully testable.
  """

  def calculate_order_total(items, discounts \\ []) do
    items
    |> calculate_subtotal()
    |> apply_discounts(discounts)
    |> add_tax()
  end

  def calculate_subtotal(items) do
    Enum.sum_by(items, fn item -> item.price * item.quantity end)
  end

  def apply_discounts(subtotal, discounts) do
    Enum.reduce(discounts, subtotal, fn
      {:percentage, pct}, total -> total * (1 - pct / 100)
      {:fixed, amount}, total -> max(0, total - amount)
    end)
  end

  def add_tax(amount, rate \\ 0.20) do
    round(amount * (1 + rate))
  end
end
```

### Impure Shell (Context)

```elixir
defmodule MyApp.Sales do
  @moduledoc """
  Shell that handles side effects: DB, external services.
  Delegates calculations to the pure core.
  """

  alias MyApp.Sales.{Order, LineItem}
  alias MyApp.Pricing.Calculator
  alias MyApp.Repo

  def calculate_order_total(order_id) do
    order = Repo.get!(Order, order_id) |> Repo.preload(:line_items)
    discounts = fetch_applicable_discounts(order.user_id)  # DB call

    # Delegate to pure core
    Calculator.calculate_order_total(order.line_items, discounts)
  end

  def checkout(order_id) do
    order = Repo.get!(Order, order_id) |> Repo.preload(:line_items)

    # Pure calculation
    total = Calculator.calculate_order_total(order.line_items)

    # Impure: persist result
    order
    |> Order.changeset(%{total: total, status: :submitted})
    |> Repo.update()
  end

  defp fetch_applicable_discounts(user_id) do
    Repo.all(from d in Discount, where: d.user_id == ^user_id)
    |> Enum.map(fn d -> {d.type, d.value} end)
  end
end
```

---

## Pattern 11: Repository Pattern - Context APIs

### Context as Repository

```elixir
defmodule MyApp.Catalog do
  @moduledoc """
  Repository-style API for product catalog.
  """

  alias MyApp.Catalog.{Product, Category}
  alias MyApp.Repo
  import Ecto.Query

  # Retrieval

  def get_product(id), do: Repo.get(Product, id)
  def get_product!(id), do: Repo.get!(Product, id)

  def get_product_by_sku(sku) do
    Repo.get_by(Product, sku: sku)
  end

  def list_products(opts \\ []) do
    Product
    |> filter_by_category(opts[:category_id])
    |> filter_by_status(opts[:status])
    |> sort_by(opts[:sort])
    |> Repo.all()
  end

  # Persistence

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  # Query builders (private)

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, category_id) do
    where(query, [p], p.category_id == ^category_id)
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status) do
    where(query, [p], p.status == ^status)
  end

  defp sort_by(query, nil), do: query
  defp sort_by(query, :price_asc), do: order_by(query, [p], asc: p.price)
  defp sort_by(query, :price_desc), do: order_by(query, [p], desc: p.price)
  defp sort_by(query, :newest), do: order_by(query, [p], desc: p.inserted_at)
end
```

---

## Pattern 12: GenServer - Stateful Domain Services

### Rate Limiter GenServer

```elixir
defmodule MyApp.RateLimiter do
  use GenServer

  @max_requests 100
  @window_ms 60_000

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def check_rate(user_id, server \\ __MODULE__) do
    GenServer.call(server, {:check_rate, user_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Process.set_label(:rate_limiter)
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:check_rate, user_id}, _from, state) do
    now = System.monotonic_time(:millisecond)
    requests = Map.get(state, user_id, [])

    # Filter to requests within window
    recent = Enum.filter(requests, fn ts -> now - ts < @window_ms end)

    if length(recent) < @max_requests do
      new_state = Map.put(state, user_id, [now | recent])
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :rate_limited}, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)

    new_state =
      state
      |> Enum.map(fn {user_id, requests} ->
        {user_id, Enum.filter(requests, fn ts -> now - ts < @window_ms end)}
      end)
      |> Enum.reject(fn {_, requests} -> requests == [] end)
      |> Map.new()

    schedule_cleanup()
    {:noreply, new_state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @window_ms)
  end
end
```

### Shopping Cart GenServer

```elixir
defmodule MyApp.CartServer do
  use GenServer

  # Client API

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via_tuple(user_id))
  end

  def add_item(user_id, product_id, quantity) do
    GenServer.call(via_tuple(user_id), {:add_item, product_id, quantity})
  end

  def get_cart(user_id) do
    GenServer.call(via_tuple(user_id), :get_cart)
  end

  def clear(user_id) do
    GenServer.cast(via_tuple(user_id), :clear)
  end

  defp via_tuple(user_id) do
    {:via, Registry, {MyApp.CartRegistry, user_id}}
  end

  # Server Callbacks

  @impl true
  def init(user_id) do
    Process.set_label({:cart, user_id})
    {:ok, %{user_id: user_id, items: %{}}}
  end

  @impl true
  def handle_call({:add_item, product_id, quantity}, _from, state) do
    current = Map.get(state.items, product_id, 0)
    new_items = Map.put(state.items, product_id, current + quantity)
    {:reply, :ok, %{state | items: new_items}}
  end

  @impl true
  def handle_call(:get_cart, _from, state) do
    {:reply, state.items, state}
  end

  @impl true
  def handle_cast(:clear, state) do
    {:noreply, %{state | items: %{}}}
  end
end
```

---

## Pattern 13: Supervisors - Fault-Tolerant Process Trees

### Application Supervisor

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      MyApp.CartSupervisor,
      MyApp.RateLimiter,
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Dynamic Supervisor for Carts

```elixir
defmodule MyApp.CartSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_cart(user_id) do
    spec = {MyApp.CartServer, user_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_cart(user_id) do
    case Registry.lookup(MyApp.CartRegistry, user_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end
end
```

---

## Pattern 14: Let It Crash - Offensive Error Handling

### Expected vs Unexpected Errors

```elixir
defmodule MyApp.FileProcessor do
  # Expected error - handle explicitly
  def process_user_file(path) do
    case File.read(path) do
      {:ok, content} -> parse_and_process(content)
      {:error, :enoent} -> {:error, :file_not_found}
      {:error, :eacces} -> {:error, :permission_denied}
    end
  end

  # Unexpected error - let it crash
  # If parse_config fails, it's a bug - we want to know about it
  def load_config! do
    Application.app_dir(:my_app, "priv/config.json")
    |> File.read!()        # Crashes if missing - that's a deployment bug
    |> JSON.decode!()      # Crashes if invalid - that's a config bug
  end

  defp parse_and_process(content) do
    # If this fails on valid content, it's a bug
    data = JSON.decode!(content)
    {:ok, transform(data)}
  end
end
```

### Using bang (!) Functions

```elixir
defmodule MyApp.DataLoader do
  # For internal/trusted data - crash on failure
  def load_seed_data! do
    "priv/seeds.json"
    |> File.read!()
    |> JSON.decode!()
    |> Enum.each(&insert_record!/1)
  end

  # For external/user data - return errors
  def import_user_data(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- JSON.decode(content) do
      {:ok, Enum.map(data, &transform/1)}
    else
      {:error, :enoent} -> {:error, "File not found"}
      {:error, %JSON.DecodeError{}} -> {:error, "Invalid JSON"}
    end
  end
end
```

---

## Pattern 15: Tagged Tuples - Result Convention

### Consistent Return Types

```elixir
defmodule MyApp.Accounts do
  # Always return tagged tuples for operations that can fail

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    # Returns {:ok, user} or {:error, changeset}
  end

  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  # Bang variant for when you know it should exist
  def get_user!(id) do
    Repo.get!(User, id)
    # Raises Ecto.NoResultsError if not found
  end

  def authenticate(email, password) do
    case get_user_by_email(email) do
      {:ok, user} ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      {:error, :not_found} ->
        # Prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end
end
```

### Structured Error Atoms

```elixir
defmodule MyApp.Payments do
  @type payment_error ::
    :insufficient_funds
    | :card_declined
    | :invalid_card
    | :gateway_timeout
    | {:validation_error, String.t()}

  @spec charge(integer(), String.t()) :: {:ok, String.t()} | {:error, payment_error()}
  def charge(amount, card_token) do
    case Gateway.charge(amount, card_token) do
      {:ok, transaction_id} ->
        {:ok, transaction_id}

      {:error, "insufficient_funds"} ->
        {:error, :insufficient_funds}

      {:error, "do_not_honor"} ->
        {:error, :card_declined}

      {:error, msg} when is_binary(msg) ->
        {:error, {:validation_error, msg}}
    end
  end
end
```

---

## Pattern 16: Reduce/Fold - Accumulator Transformations

### Basic Reduce

```elixir
defmodule MyApp.Stats do
  # Simple sum — prefer Enum.sum_by/2 (1.18+)
  def total_revenue(orders) do
    Enum.sum_by(orders, & &1.total)
  end

  # Building a map — reduce is the right tool
  def orders_by_status(orders) do
    Enum.reduce(orders, %{}, fn order, acc ->
      Map.update(acc, order.status, [order], &[order | &1])
    end)
  end

  # Multiple accumulators with tuple
  def sum_and_count(numbers) do
    {sum, count} = Enum.reduce(numbers, {0, 0}, fn n, {s, c} ->
      {s + n, c + 1}
    end)

    %{sum: sum, count: count, average: sum / count}
  end
end
```

### Complex Reduction

```elixir
defmodule MyApp.OrderBuilder do
  def build_order(items, user) do
    initial = %{
      items: [],
      subtotal: 0,
      discounts: [],
      errors: []
    }

    result = Enum.reduce(items, initial, fn item, acc ->
      case validate_and_price(item) do
        {:ok, priced_item} ->
          %{acc |
            items: [priced_item | acc.items],
            subtotal: acc.subtotal + priced_item.total
          }

        {:error, reason} ->
          %{acc | errors: [{item.product_id, reason} | acc.errors]}
      end
    end)

    if result.errors == [] do
      {:ok, finalize_order(result, user)}
    else
      {:error, result.errors}
    end
  end

  defp validate_and_price(item) do
    {:ok, %{item | total: item.price * item.quantity}}
  end

  defp finalize_order(result, user) do
    %Order{
      items: Enum.reverse(result.items),
      subtotal: result.subtotal,
      user_id: user.id
    }
  end
end
```

---

## Pattern 17: Comprehensions - Declarative Generation

### Basic Comprehension

```elixir
# Instead of Enum.map + Enum.filter
# Bad
Enum.filter(users, fn u -> u.active end) |> Enum.map(fn u -> u.email end)

# Good - comprehension combines both
for user <- users, user.active, do: user.email
```

### Multiple Generators (Cartesian Product)

```elixir
defmodule MyApp.Inventory do
  def generate_variants(product, sizes, colors) do
    for size <- sizes,
        color <- colors do
      %Variant{
        product_id: product.id,
        sku: "#{product.sku}-#{size}-#{color}",
        size: size,
        color: color
      }
    end
  end
end

# Usage
generate_variants(product, ["S", "M", "L"], ["red", "blue"])
# Returns 6 variants (3 sizes x 2 colors)
```

### Collecting Into Different Types

```elixir
defmodule MyApp.DataTransform do
  # Into a map
  def users_by_id(users) do
    for user <- users, into: %{} do
      {user.id, user}
    end
  end

  # Into a MapSet
  def unique_emails(users) do
    for user <- users, into: MapSet.new() do
      user.email
    end
  end

  # Into a string (binary)
  def emails_csv(users) do
    for user <- users, into: "" do
      "#{user.email},"
    end
  end
end
```

### Nested Comprehension with Filters

```elixir
defmodule MyApp.Reports do
  def active_order_items(orders) do
    for order <- orders,
        order.status in [:pending, :processing],
        item <- order.items,
        item.quantity > 0 do
      %{
        order_id: order.id,
        product_id: item.product_id,
        quantity: item.quantity
      }
    end
  end
end
```

---

## Pattern 18: Keyword Lists & Options - Flexible Parameters

### Options as Last Argument

```elixir
defmodule MyApp.Mailer do
  @default_opts [
    format: :html,
    priority: :normal,
    track_opens: true
  ]

  def send_email(to, subject, body, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    %Email{
      to: to,
      subject: subject,
      body: body,
      format: Keyword.get(opts, :format),
      priority: Keyword.get(opts, :priority),
      track_opens: Keyword.get(opts, :track_opens)
    }
    |> deliver()
  end
end

# Usage
Mailer.send_email("user@example.com", "Hello", "Body")
Mailer.send_email("user@example.com", "Hello", "Body", format: :text, priority: :high)
```

### Pattern Matching on Options

```elixir
defmodule MyApp.Query do
  def list_users(opts \\ [])

  def list_users(opts) when is_list(opts) do
    User
    |> apply_filters(opts)
    |> apply_sorting(opts)
    |> apply_pagination(opts)
    |> Repo.all()
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, q -> where(q, [u], u.status == ^status)
      {:role, role}, q -> where(q, [u], u.role == ^role)
      {:search, term}, q -> where(q, [u], ilike(u.name, ^"%#{term}%"))
      _, q -> q  # Ignore unknown options
    end)
  end

  defp apply_sorting(query, opts) do
    case Keyword.get(opts, :sort) do
      nil -> query
      {:asc, field} -> order_by(query, [u], asc: field(u, ^field))
      {:desc, field} -> order_by(query, [u], desc: field(u, ^field))
    end
  end

  defp apply_pagination(query, opts) do
    query
    |> limit(^Keyword.get(opts, :limit, 20))
    |> offset(^Keyword.get(opts, :offset, 0))
  end
end

# Usage
Query.list_users(status: :active, sort: {:desc, :inserted_at}, limit: 10)
```

---

## Pattern 19: Type-Aware Code (1.17+)

### Leveraging the Type System

```elixir
# The compiler infers that `data` must be a map with :foo and :bar keys
# containing integer() or float() values — no runtime check needed
def add_foo_and_bar(data) do
  data.foo + data.bar
end

# Cross-clause narrowing: after matching nil in clause 1,
# clause 2 knows the value is not nil
def process(nil), do: {:error, :missing}
def process(value), do: {:ok, String.upcase(value)}

# Use Map.fetch!/2 to help type system track key presence
def extract_name(user_map) do
  name = Map.fetch!(user_map, :name)
  String.trim(name)
end
```

### Distinguishing Maps from Structs

```elixir
# is_non_struct_map/1 guard (1.17+) solves the %{} matches everything problem
def serialize(data) when is_non_struct_map(data) do
  JSON.encode!(data)
end

def serialize(%User{} = user) do
  JSON.encode!(%{id: user.id, name: user.name})
end
```

### Built-in JSON (1.18+)

```elixir
# Encode/decode without external dependency
JSON.encode!(%{name: "Alice", age: 30})
JSON.decode!("{\"name\":\"Alice\"}")

# Custom encoding via protocol derive
defmodule User do
  @derive {JSON.Encoder, only: [:id, :name, :email]}
  defstruct [:id, :name, :email, :password_hash]
end
```

### Duration and Timeouts (1.17+)

```elixir
# Calendar-aware date shifts
~D[2024-01-31] |> Date.shift(month: 1)
# => ~D[2024-02-29] (leap year aware)

# Timeout normalization — replaces manual millisecond math
Process.send_after(pid, :wake_up, to_timeout(hour: 1))
GenServer.call(server, :request, to_timeout(second: 30))
```

### Parameterized ExUnit Tests (1.18+)

```elixir
defmodule MyApp.ParserTest do
  use ExUnit.Case,
    async: true,
    parameterize: [
      %{format: :json, parser: MyApp.JSONParser},
      %{format: :csv, parser: MyApp.CSVParser}
    ]

  test "parses valid input", %{parser: parser} do
    assert {:ok, _data} = parser.parse(valid_input())
  end

  test "returns error on invalid input", %{parser: parser} do
    assert {:error, _reason} = parser.parse(invalid_input())
  end
end
```

### Modern Enum Functions (1.18+)

```elixir
# Before: Enum.map + Enum.sum
orders |> Enum.map(& &1.total) |> Enum.sum()

# After: Enum.sum_by/2
Enum.sum_by(orders, & &1.total)

# Also: Enum.product_by/2
Enum.product_by(items, & &1.quantity)
```
