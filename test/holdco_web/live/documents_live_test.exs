defmodule HoldcoWeb.DocumentsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /documents" do
    test "renders documents page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "Documents"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "page-title"
    end

    test "documents nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ ~r/href="\/documents"[^>]*class="active"/s
    end
  end
end
