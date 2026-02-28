defmodule HoldcoWeb.TransferPricingLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Transfer Pricing page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/transfer-pricing")
      assert html =~ "Transfer Pricing"
      assert html =~ "Related party pricing studies and documentation"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/transfer-pricing")
      assert html =~ "Total Studies"
      assert html =~ "Needing Adjustment"
      assert html =~ "Total Adjustment Amount"
      assert html =~ "Methods Used"
    end

    test "shows studies table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/transfer-pricing")
      assert html =~ "Studies"
      assert html =~ "Study Name"
      assert html =~ "Company"
      assert html =~ "Year"
      assert html =~ "Related Party"
      assert html =~ "Method"
      assert html =~ "Conclusion"
    end

    test "shows empty state when no studies exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/transfer-pricing")
      assert html =~ "No transfer pricing studies found."
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/transfer-pricing")
      assert html =~ "All Companies"
    end

    test "displays an existing transfer pricing study", %{conn: conn} do
      transfer_pricing_study_fixture(%{study_name: "Interco Licensing Study"})
      {:ok, _live, html} = live(conn, ~p"/transfer-pricing")
      assert html =~ "Interco Licensing Study"
    end
  end

  describe "show_form and close_form" do
    test "show_form opens the add study dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      html = render_click(view, "show_form")
      assert html =~ "Add Study"
      assert html =~ "Study Name *"
      assert html =~ "Company *"
      assert html =~ "Fiscal Year *"
      assert html =~ "Related Party Name *"
    end

    test "close_form hides the dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "filter_company" do
    test "filtering by company updates the list", %{conn: conn} do
      company = company_fixture(%{name: "TP Filter Corp"})
      transfer_pricing_study_fixture(%{company: company, study_name: "Filtered Study"})

      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Filtered Study"
    end

    test "filtering with empty company_id shows all studies", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "Studies"
    end
  end

  describe "save (create)" do
    test "creating a transfer pricing study with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "transfer_pricing_study" => %{
            "study_name" => "New IP Licensing Study",
            "company_id" => to_string(company.id),
            "fiscal_year" => "2025",
            "related_party_name" => "Subsidiary LLC",
            "transaction_type" => "ip_licensing",
            "transaction_amount" => "500000",
            "currency" => "USD",
            "method" => "cup",
            "conclusion" => "within_range",
            "documentation_status" => "in_progress"
          }
        })

      assert html =~ "Transfer pricing study added"
      assert html =~ "New IP Licensing Study"
    end

    test "creating a study with missing required fields shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "transfer_pricing_study" => %{
            "study_name" => "",
            "company_id" => "",
            "fiscal_year" => "",
            "related_party_name" => ""
          }
        })

      assert html =~ "Failed to add study"
    end
  end

  describe "edit and update" do
    test "edit event opens edit form with existing data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      study = transfer_pricing_study_fixture(%{study_name: "Editable Study"})

      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      html = render_click(view, "edit", %{"id" => to_string(study.id)})
      assert html =~ "Edit Study"
      assert html =~ "Editable Study"
    end

    test "updating a study with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      study = transfer_pricing_study_fixture(%{company: company, study_name: "Old Study Name"})

      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      render_click(view, "edit", %{"id" => to_string(study.id)})

      html =
        render_click(view, "update", %{
          "transfer_pricing_study" => %{
            "study_name" => "Updated Study Name",
            "company_id" => to_string(company.id),
            "fiscal_year" => "2025",
            "related_party_name" => "Updated Related Party",
            "transaction_type" => "services",
            "method" => "tnmm",
            "conclusion" => "below_range",
            "documentation_status" => "complete"
          }
        })

      assert html =~ "Transfer pricing study updated"
      assert html =~ "Updated Study Name"
    end
  end

  describe "delete" do
    test "deleting a study removes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      study = transfer_pricing_study_fixture(%{study_name: "Doomed Study"})

      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      assert render(view) =~ "Doomed Study"

      html = render_click(view, "delete", %{"id" => to_string(study.id)})
      assert html =~ "Transfer pricing study deleted"
      refute html =~ "Doomed Study"
    end
  end

  describe "noop" do
    test "noop event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transfer-pricing")
      html = render_click(view, "noop")
      assert html =~ "Transfer Pricing"
    end
  end
end
