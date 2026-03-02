defmodule Holdco.AnalyticsTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "Report Templates" do
    test "list_report_templates/0 returns all templates" do
      rt = report_template_fixture(%{name: "Monthly Report"})
      templates = Analytics.list_report_templates()
      assert length(templates) >= 1
      assert Enum.any?(templates, &(&1.id == rt.id))
    end

    test "list_report_templates/1 filters by user_id" do
      u1 = Holdco.AccountsFixtures.user_fixture()
      u2 = Holdco.AccountsFixtures.user_fixture()
      rt1 = report_template_fixture(%{user: u1, name: "User1 Report"})
      _rt2 = report_template_fixture(%{user: u2, name: "User2 Report"})

      templates = Analytics.list_report_templates(u1.id)
      assert length(templates) == 1
      assert hd(templates).id == rt1.id
    end

    test "get_report_template!/1 returns the template" do
      rt = report_template_fixture(%{name: "Get Template"})
      found = Analytics.get_report_template!(rt.id)
      assert found.id == rt.id
      assert found.name == "Get Template"
    end

    test "get_report_template!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_report_template!(0)
      end
    end

    test "create_report_template/1 with valid attrs" do
      user = Holdco.AccountsFixtures.user_fixture()

      assert {:ok, rt} =
               Analytics.create_report_template(%{
                 user_id: user.id,
                 name: "Quarterly Board Pack",
                 frequency: "quarterly"
               })

      assert rt.name == "Quarterly Board Pack"
      assert rt.frequency == "quarterly"
    end

    test "create_report_template/1 fails without name" do
      assert {:error, changeset} = Analytics.create_report_template(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_report_template/1 validates frequency" do
      assert {:error, changeset} =
               Analytics.create_report_template(%{name: "Bad Freq", frequency: "invalid"})

      assert %{frequency: _} = errors_on(changeset)
    end

    test "update_report_template/2 updates successfully" do
      rt = report_template_fixture(%{name: "Old Report"})
      assert {:ok, updated} = Analytics.update_report_template(rt, %{name: "New Report"})
      assert updated.name == "New Report"
    end

    test "delete_report_template/1 deletes the template" do
      rt = report_template_fixture()
      assert {:ok, _} = Analytics.delete_report_template(rt)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_report_template!(rt.id)
      end
    end
  end
end
