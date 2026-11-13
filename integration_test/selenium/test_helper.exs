ExUnit.configure(max_cases: 2, exclude: [pending: true, skip_selenium: true])

# Load support files
Code.require_file("../support/test_server.ex", __DIR__)
Code.require_file("../support/pages/index_page.ex", __DIR__)
Code.require_file("../support/pages/page_1.ex", __DIR__)
Code.require_file("../support/session_case.ex", __DIR__)
Code.require_file("../support/helpers.ex", __DIR__)

{:ok, server} = Wallaby.Integration.TestServer.start()
Application.put_env(:wallaby, :base_url, server.base_url)

# Requires a Selenium 4+ server with a Chrome node, e.g.:
#   docker run -d -p 4444:4444 selenium/standalone-chrome
Application.put_env(:wallaby, :selenium,
  remote_url: System.get_env("SELENIUM_URL", "http://localhost:4444/"),
  client: Wallaby.Webdriver.W3CClient,
  capabilities: %{
    browserName: "chrome",
    "goog:chromeOptions": %{
      args: ["--headless"]
    }
  }
)

ExUnit.start()
