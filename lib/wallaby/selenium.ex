defmodule Wallaby.Selenium do
  @moduledoc """
  The Selenium driver uses [Selenium Server](https://github.com/SeleniumHQ/selenium) to power many types of browsers (Chrome, Firefox, Edge, etc).

  ## Usage

  Start a Wallaby Session using this driver with the following command:

  ```
  {:ok, session} = Wallaby.start_session()
  ```

  ## Configuration

  ### Capabilities

  These capabilities will override the default capabilities.

  ```
  config :wallaby,
    selenium: [
      capabilities: %{
        # something
      }
    ]
  ```

  ## Default Capabilities

  By default, Selenium will use the following capabilities

  You can read more about capabilities in the [JSON Wire Protocol](https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol#capabilities-json-object) documentation.

  ```elixir
  %{
    javascriptEnabled: true,
    browserName: "firefox",
    "moz:firefoxOptions": %{
      args: ["-headless"]
    }
  }
  ```

  ## Notes

  - Requires [selenium-server-standalone](https://www.seleniumhq.org/download/) to be running on port 4444. Wallaby does _not_ manage the start/stop of the Selenium server.
  - Requires [GeckoDriver](https://github.com/mozilla/geckodriver) to be installed in your path when using [Firefox](https://www.mozilla.org/en-US/firefox/new/). Firefox is used by default.
  """

  use Supervisor

  @behaviour Wallaby.Driver

  alias Wallaby.Helpers.KeyCodes
  alias Wallaby.Metadata
  alias Wallaby.WebdriverClient
  alias Wallaby.{Driver, Element, Session}
  alias Wallaby.Webdriver.{JWPClient, W3CClient}

  @typedoc """
  Options to pass to Wallaby.start_session/1

  ```elixir
  Wallaby.start_session(
    remote_url: "http://selenium_url",
    capabilities: %{browserName: "firefox"}
  )
  ```
  """
  @type start_session_opts ::
          {:remote_url, String.t()}
          | {:capabilities, map}

  @doc false
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @doc false
  def init(_) do
    Supervisor.init([], strategy: :one_for_one)
  end

  @doc false
  def validate do
    :ok
  end

  @doc false
  @spec start_session([start_session_opts]) :: Wallaby.Driver.on_start_session() | no_return
  def start_session(opts \\ []) do
    base_url = Keyword.get(opts, :remote_url, "http://localhost:4444/wd/hub/")
    client = Keyword.get(opts, :client, JWPClient)
    create_session = Keyword.get(opts, :create_session_fn, &client.create_session/2)
    capabilities = Keyword.get(opts, :capabilities, capabilities_from_config(opts))

    with {:ok, session_id} <- create_session.(base_url, capabilities) do
      session = %Session{
        session_url: base_url <> "session/#{session_id}",
        url: base_url <> "session/#{session_id}",
        id: session_id,
        driver: __MODULE__,
        client: client,
        capabilities: capabilities
      }

      if window_size = Keyword.get(opts, :window_size),
        do: {:ok, _} = set_window_size(session, window_size[:width], window_size[:height])

      {:ok, session}
    end
  end

  defp capabilities_from_config(opts) do
    :wallaby
    |> Application.get_env(:selenium, [])
    |> Keyword.get(:capabilities, default_capabilities(opts))
  end

  @doc false
  @spec end_session(Session.t()) :: :ok
  def end_session(%{client: client} = session) do
    client.delete_session(session)
    :ok
  end

  @doc false
  def blank_page?(session) do
    case current_url(session) do
      {:ok, url} ->
        url == "about:blank"

      _ ->
        false
    end
  end

  @doc false
  # defdelegate window_handle(session), to: session.client
  def window_handle(%{client: client} = session), do: client.window_handle(session)

  @doc false
  # defdelegate window_handles(session), to: session.client
  def window_handles(%{client: client} = session), do: client.window_handles(session)

  @doc false
  # defdelegate focus_window(session, window_handle), to: WebdriverClient
  def focus_window(%{client: client} = session), do: client.focus_window(session)

  @doc false
  # defdelegate close_window(session), to: WebdriverClient
  def close_window(%{client: client} = session), do: client.close_window(session)

  @doc false
  # defdelegate get_window_size(session), to: WebdriverClient
  def get_window_size(%{client: client} = session), do: client.get_window_size(session)

  @doc false
  # defdelegate set_window_size(session, width, height), to: WebdriverClient
  def set_window_size(%{client: client} = session, width, height),
    do: client.set_window_size(session, width, height)

  @doc false
  # defdelegate get_window_position(session), to: WebdriverClient
  def get_window_position(%{client: client} = session), do: client.get_window_position(session)

  @doc false
  # defdelegate set_window_position(session, x, y), to: WebdriverClient
  def set_window_position(%{client: client} = session, x, y),
    do: client.set_window_position(session, x, y)

  @doc false
  # defdelegate maximize_window(session), to: WebdriverClient
  def maximize_window(%{client: client} = session), do: client.maximize_window(session)

  @doc false
  # defdelegate focus_frame(session, frame), to: WebdriverClient
  def focus_frame(%{client: client} = session, frame), do: client.focus_frame(session, frame)

  @doc false
  # defdelegate focus_parent_frame(session), to: WebdriverClient
  def focus_parent_frame(%{client: client} = session), do: client.focus_parent_frame(session)

  @doc false
  # defdelegate accept_alert(session, fun), to: WebdriverClient
  def accept_alert(%{client: client} = session, fun), do: client.accept_alert(session, fun)

  @doc false
  # defdelegate dismiss_alert(session, fun), to: WebdriverClient
  def dismiss_alert(%{client: client} = session, fun), do: client.dismiss_alert(session, fun)

  @doc false
  # defdelegate accept_confirm(session, fun), to: WebdriverClient
  def accept_confirm(%{client: client} = session, fun), do: client.accept_confirm(session, fun)

  @doc false
  # defdelegate dismiss_confirm(session, fun), to: WebdriverClient
  def dismiss_confirm(%{client: client} = session, fun), do: client.dismiss_confirm(session, fun)

  @doc false
  # defdelegate accept_prompt(session, input, fun), to: WebdriverClient
  def accept_prompt(%{client: client} = session, fun), do: client.accept_prompt(session, fun)

  @doc false
  # defdelegate dismiss_prompt(session, fun), to: WebdriverClient
  def dismiss_prompt(%{client: client} = session, fun), do: client.dismiss_prompt(session, fun)

  @doc false
  # defdelegate take_screenshot(session_or_element), to: WebdriverClient
  def take_screenshot(%{client: client} = session, fun), do: client.take_screenshot(session, fun)

  @doc false
  def cookies(%{client: client} = session), do: client.cookies(session)

  @doc false
  def current_path(%Session{client: client} = session) do
    with {:ok, url} <- client.current_url(session),
         uri <- URI.parse(url),
         {:ok, path} <- Map.fetch(uri, :path),
         do: {:ok, path}
  end

  @doc false
  def current_url(%{client: client} = session), do: client.current_url(session)

  @doc false
  def page_source(%{client: client} = session), do: client.page_source(session)

  @doc false
  def page_title(%{client: client} = session), do: client.page_title(session)

  @doc false
  def set_cookie(%{client: client} = session, key, value),
    do: client.set_cookie(session, key, value)

  @doc false
  def visit(%{client: client} = session, path), do: client.visit(session, path)

  @doc false
  def attribute(%Element{client: client} = element, name), do: client.attribute(element, name)

  @doc false
  @spec clear(Element.t()) :: {:ok, nil} | {:error, Driver.reason()}
  def clear(%Element{client: client} = element), do: client.clear(element)

  @doc false
  def click(%Element{client: client} = element), do: client.click(element)

  @doc false
  def click(%{client: client} = parent, button), do: client.click(parent, button)

  @doc false
  def button_down(%{client: client} = parent, button), do: client.button_down(parent, button)

  @doc false
  def button_up(%{client: client} = parent, button), do: client.button_up(parent, button)

  @doc false
  def double_click(%{client: client} = parent), do: client.double_click(parent)

  @doc false
  def hover(%Element{client: client} = element), do: client.move_mouse_to(nil, element)

  @doc false
  def move_mouse_by(%{client: client} = session, x_offset, y_offset),
    do: client.move_mouse_to(session, nil, x_offset, y_offset)

  @doc false
  def displayed(%Element{client: client} = element), do: client.displayed(element)

  @doc false
  def selected(%Element{client: client} = element), do: client.selected(element)

  @doc false
  @spec set_value(Element.t(), String.t()) :: {:ok, nil} | {:error, Driver.reason()}
  def set_value(%Element{client: client} = element, value), do: client.set_value(element, value)

  @doc false
  def text(%Element{client: client} = element), do: client.text(element)

  @doc false
  def find_elements(%{client: client} = parent, compiled_query),
    do: client.find_elements(parent, compiled_query)

  @doc false
  def execute_script(%{client: client} = parent, script, arguments \\ []),
    do: client.execute_script(parent, script, arguments)

  @doc false
  def execute_script_async(%{client: client} = parent, script, arguments \\ []),
    do: client.execute_script_async(parent, script, arguments)

  @doc """
  Simulates typing into an element.

  When sending keys to an element and `keys` is identified as
  a local file, the local file is uploaded to the
  Selenium server, returning a file path which is then
  set to the file input we are interacting with.

  We then call the `WebdriverClient.send_keys/2` to set the
  remote file path as the input's value.
  """
  @spec send_keys(Session.t() | Element.t(), list()) :: {:ok, any}
  def send_keys(%Session{client: client} = session, keys), do: client.send_keys(session, keys)

  def send_keys(%Element{client: client} = element, keys) do
    keys =
      case Enum.all?(keys, &is_local_file?(&1)) do
        true ->
          keys
          |> Enum.map(fn key -> upload_file(element, key) end)
          |> Enum.intersperse("\n")

        false ->
          keys
      end

    client.send_keys(element, keys)
  end

  def element_size(%{client: client} = element), do: client.element_size(element)

  def element_location(%{client: client} = element), do: client.element_location(element)

  @doc false
  def default_capabilities(opts \\ []) do
    user_agent =
      Metadata.append(
        "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
        opts[:metadata]
      )

    %{
      javascriptEnabled: true,
      browserName: "firefox",
      "moz:firefoxOptions": %{
        args: ["-headless"],
        prefs: %{
          "general.useragent.override" => user_agent
        }
      }
    }
  end

  # Create a zip file containing our local file
  defp create_zipfile(zipfile, filename) do
    {:ok, ^zipfile} =
      :zip.create(
        zipfile,
        [String.to_charlist(Path.basename(filename))],
        cwd: String.to_charlist(Path.dirname(filename))
      )

    zipfile
  end

  # Base64 encode the zipfile for transfer to remote Selenium
  defp encode_zipfile(zipfile) do
    File.open!(zipfile, [:read, :raw], fn f ->
      f
      |> IO.binread(:all)
      |> Base.encode64()
    end)
  end

  defp is_local_file?(file) do
    file
    |> keys_to_binary()
    |> File.exists?()
  end

  defp keys_to_binary(keys) do
    keys
    |> KeyCodes.chars()
    |> IO.iodata_to_binary()
  end

  # Makes an uploadable file for JSONWireProtocol
  defp make_file(filename) do
    System.tmp_dir!()
    |> Path.join("#{random_filename()}.zip")
    |> String.to_charlist()
    |> create_zipfile(filename)
    |> encode_zipfile()
  end

  # Generate a random filename
  defp random_filename do
    Base.encode32(:crypto.strong_rand_bytes(20))
  end

  # Uploads a local file to remote Selenium server
  # Returns the remote file's uploaded location
  defp upload_file(element, filename) do
    zip64 = make_file(filename)
    endpoint = element.session_url <> "/file"

    with {:ok, response} <- Wallaby.HTTPClient.request(:post, endpoint, %{file: zip64}) do
      Map.fetch!(response, "value")
    end
  end
end
