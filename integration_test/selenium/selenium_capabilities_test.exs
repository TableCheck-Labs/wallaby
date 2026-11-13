defmodule Wallaby.Integration.SeleniumCapabilitiesTest do
  use ExUnit.Case, async: false
  use Wallaby.DSL

  import Wallaby.SettingsTestHelpers

  alias Wallaby.Integration.SessionCase
  alias Wallaby.Webdriver.W3CClient

  setup do
    ensure_setting_is_reset(:wallaby, :selenium)
  end

  describe "capabilities" do
    test "starts a session with W3C client" do
      {:ok, session} = SessionCase.start_test_session()

      assert session.client == W3CClient

      session
      |> visit("page_1.html")
      |> assert_has(Query.text("Page 1"))

      assert :ok = Wallaby.end_session(session)
    end

    test "reads capabilities from application config" do
      expected_capabilities = %{
        browserName: "chrome",
        "goog:chromeOptions": %{
          args: ["--headless"]
        }
      }

      Application.put_env(:wallaby, :selenium,
        client: W3CClient,
        capabilities: expected_capabilities
      )

      create_session_fn = fn url, capabilities ->
        assert capabilities == expected_capabilities

        W3CClient.create_session(url, capabilities)
      end

      {:ok, session} = SessionCase.start_test_session(create_session_fn: create_session_fn)

      session
      |> visit("page_1.html")
      |> assert_has(Query.text("Page 1"))

      assert :ok = Wallaby.end_session(session)
    end
  end
end
