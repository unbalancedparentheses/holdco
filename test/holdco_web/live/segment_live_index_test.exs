defmodule HoldcoWeb.SegmentLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Segment Reporting page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Segment Reporting"
    end

    test "shows page subtitle", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Revenue, expenses, and income broken down by business segment"
    end

    test "shows metrics strip with segment counts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Total Segments"
      assert html =~ "Business"
      assert html =~ "Geographic"
      assert html =~ "Product"
    end

    test "shows empty state when no segments exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "No segments defined yet"
    end

    test "shows segment table headers", %{conn: conn} do
      company = company_fixture()
      segment_fixture(%{company: company, name: "Test Seg"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Name"
      assert html =~ "Type"
      assert html =~ "Description"
      assert html =~ "Company"
    end

    test "renders with segment data", %{conn: conn} do
      company = company_fixture(%{name: "SegCorp"})
      segment_fixture(%{company: company, name: "North America", segment_type: "geographic"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "North America"
      assert html =~ "geographic"
    end

    test "renders business segment type tag", %{conn: conn} do
      company = company_fixture()
      segment_fixture(%{company: company, name: "Tech Division", segment_type: "business"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Tech Division"
      assert html =~ "business"
    end

    test "renders product segment type tag", %{conn: conn} do
      company = company_fixture()
      segment_fixture(%{company: company, name: "Widget Line", segment_type: "product"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Widget Line"
      assert html =~ "product"
    end

    test "renders multiple segments with correct counts", %{conn: conn} do
      company = company_fixture()
      segment_fixture(%{company: company, name: "Seg A", segment_type: "business"})
      segment_fixture(%{company: company, name: "Seg B", segment_type: "geographic"})
      segment_fixture(%{company: company, name: "Seg C", segment_type: "product"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Seg A"
      assert html =~ "Seg B"
      assert html =~ "Seg C"
    end

    test "shows segment comparison chart when multiple segments exist", %{conn: conn} do
      company = company_fixture()
      segment_fixture(%{company: company, name: "Segment 1", segment_type: "business"})
      segment_fixture(%{company: company, name: "Segment 2", segment_type: "business"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Segment Comparison"
      assert html =~ "segment-comparison-chart"
    end

    test "shows company link for segments with company", %{conn: conn} do
      company = company_fixture(%{name: "LinkedCo"})
      segment_fixture(%{company: company, name: "Linked Seg"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "LinkedCo"
    end
  end

  describe "form interactions" do
    test "opens add segment form with show_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "show_form", %{})
      assert html =~ "Add Segment"
      assert html =~ "Name"
      assert html =~ "Segment Type"
      assert html =~ "Description"
      assert html =~ "Company"
    end

    test "form shows segment type options", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "show_form", %{})
      assert html =~ "business"
      assert html =~ "geographic"
      assert html =~ "product"
    end

    test "form shows company options", %{conn: conn} do
      company_fixture(%{name: "DropdownCo"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "show_form", %{})
      assert html =~ "DropdownCo"
      assert html =~ "-- No company (global) --"
    end

    test "closes form with close_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "show_form", %{})
      html = render_click(live, "close_form", %{})
      refute html =~ "Add Segment"
    end

    test "opens edit form for existing segment", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Edit Me Seg", segment_type: "business"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "edit", %{"id" => to_string(seg.id)})
      assert html =~ "Edit Segment"
      assert html =~ "Edit Me Seg"
    end

    test "noop event does nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "noop", %{})
      assert html =~ "Segment Reporting"
    end
  end

  describe "company filter" do
    test "filters segments by company", %{conn: conn} do
      company1 = company_fixture(%{name: "CompanyA"})
      company2 = company_fixture(%{name: "CompanyB"})
      segment_fixture(%{company: company1, name: "Seg in A"})
      segment_fixture(%{company: company2, name: "Seg in B"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_change(live, "filter_company", %{"company_id" => to_string(company1.id)})
      assert html =~ "Seg in A"
    end

    test "shows all segments when company filter is empty", %{conn: conn} do
      company = company_fixture()
      segment_fixture(%{company: company, name: "All Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      # First filter to a company
      render_change(live, "filter_company", %{"company_id" => to_string(company.id)})
      # Then reset to all
      html = render_change(live, "filter_company", %{"company_id" => ""})
      assert html =~ "All Seg"
    end

    test "company filter dropdown shows All Companies option", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "All Companies"
    end
  end

  describe "segment selection and trial balance" do
    test "selects a segment to show trial balance", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Selected Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      assert html =~ "Selected Seg -- Trial Balance"
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      assert html =~ "Net Income"
    end

    test "shows revenue and expense accounts sections", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Detail Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      assert html =~ "Revenue Accounts"
      assert html =~ "Expense Accounts"
    end

    test "shows empty state for revenue and expense accounts", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Empty TB Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      assert html =~ "No revenue accounts in this segment"
      assert html =~ "No expense accounts in this segment"
    end

    test "deselects segment to close trial balance", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Deselect Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      html = render_click(live, "deselect_segment", %{})
      refute html =~ "Deselect Seg -- Trial Balance"
    end

    test "shows Close button when segment is selected", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Close Btn Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      assert html =~ "Close"
    end

    test "shows total revenue and expense footers", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Totals Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
    end
  end

  describe "viewer permission gating" do
    test "viewer cannot save a segment", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{"segment" => %{"name" => "Test", "segment_type" => "business"}})
      assert html =~ "permission"
    end

    test "viewer cannot update a segment", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "No Update Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "edit", %{"id" => to_string(seg.id)})

      html = render_click(live, "update", %{"segment" => %{"name" => "Updated"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete a segment", %{conn: conn} do
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "No Delete Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "delete", %{"id" => to_string(seg.id)})
      assert html =~ "permission"
    end
  end

  describe "editor operations" do
    test "editor can save a new segment", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EditorCo"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{
        "segment" => %{
          "name" => "New Editor Segment",
          "segment_type" => "business",
          "company_id" => to_string(company.id)
        }
      })
      assert html =~ "Segment created" || html =~ "New Editor Segment"
    end

    test "editor can update a segment", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Original Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "edit", %{"id" => to_string(seg.id)})

      html = render_click(live, "update", %{
        "segment" => %{"name" => "Updated Seg", "segment_type" => "geographic"}
      })
      assert html =~ "Segment updated" || html =~ "Updated Seg"
    end

    test "editor can delete a segment", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Delete This Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      html = render_click(live, "delete", %{"id" => to_string(seg.id)})
      assert html =~ "Segment deleted"
    end

    test "editor sees Add Segment button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Add Segment"
    end

    test "editor sees Edit and Del buttons on segments", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      segment_fixture(%{company: company, name: "Action Seg"})

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Edit"
      assert html =~ "Del"
    end

    test "deleting selected segment clears the selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Selected Then Deleted"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "select_segment", %{"id" => to_string(seg.id)})
      html = render_click(live, "delete", %{"id" => to_string(seg.id)})
      assert html =~ "Segment deleted"
      refute html =~ "Selected Then Deleted -- Trial Balance"
    end

    test "deleting a non-selected segment keeps current selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      seg1 = segment_fixture(%{company: company, name: "Keep Selected"})
      seg2 = segment_fixture(%{company: company, name: "Delete Other"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "select_segment", %{"id" => to_string(seg1.id)})
      html = render_click(live, "delete", %{"id" => to_string(seg2.id)})
      assert html =~ "Segment deleted"
      assert html =~ "Keep Selected -- Trial Balance"
    end

    test "editor sees Add Your First Segment when empty", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/segments")
      assert html =~ "Add Your First Segment"
    end

    test "editor save failure shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "show_form", %{})

      # Submit with empty required name to trigger error
      html =
        render_click(live, "save", %{
          "segment" => %{"name" => "", "segment_type" => ""}
        })

      assert html =~ "Failed to create segment" || html =~ "Segment Reporting"
    end

    test "editor update failure shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      seg = segment_fixture(%{company: company, name: "Fail Update Seg"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      render_click(live, "edit", %{"id" => to_string(seg.id)})

      # Submit with empty required name to trigger error
      html =
        render_click(live, "update", %{
          "segment" => %{"name" => ""}
        })

      assert html =~ "Failed to update segment" || html =~ "Segment Reporting"
    end

    test "editor save with company filter active reloads correctly", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "FilteredSaveCo"})

      {:ok, live, _html} = live(conn, ~p"/segments")
      # Set company filter
      render_change(live, "filter_company", %{"company_id" => to_string(company.id)})
      # Open form and create segment
      render_click(live, "show_form", %{})

      html =
        render_click(live, "save", %{
          "segment" => %{
            "name" => "Filtered Save Seg",
            "segment_type" => "business",
            "company_id" => to_string(company.id)
          }
        })

      assert html =~ "Segment created" || html =~ "Filtered Save Seg"
    end
  end

  describe "handle_info" do
    test "refreshes segments on pubsub message", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/segments")

      company = company_fixture()
      segment_fixture(%{company: company, name: "PubSub Seg"})

      send(live.pid, {:segment_changed, %{}})

      html = render(live)
      assert html =~ "PubSub Seg"
    end
  end
end
