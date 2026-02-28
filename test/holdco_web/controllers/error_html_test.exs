defmodule HoldcoWeb.ErrorHTMLTest do
  use HoldcoWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    assert render_to_string(HoldcoWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(HoldcoWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end

  test "renders 400.html" do
    assert render_to_string(HoldcoWeb.ErrorHTML, "400", "html", []) == "Bad Request"
  end

  test "renders 403.html" do
    assert render_to_string(HoldcoWeb.ErrorHTML, "403", "html", []) == "Forbidden"
  end

  test "renders 422.html" do
    assert render_to_string(HoldcoWeb.ErrorHTML, "422", "html", []) == "Unprocessable Content"
  end

  test "renders 503.html" do
    assert render_to_string(HoldcoWeb.ErrorHTML, "503", "html", []) == "Service Unavailable"
  end

  test "render/2 returns status message for any template" do
    assert HoldcoWeb.ErrorHTML.render("404.html", %{}) == "Not Found"
    assert HoldcoWeb.ErrorHTML.render("500.html", %{}) == "Internal Server Error"
  end
end
