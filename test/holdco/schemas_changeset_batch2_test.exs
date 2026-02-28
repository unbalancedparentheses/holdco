defmodule Holdco.SchemasChangesetBatch2Test do
  use Holdco.DataCase, async: true

  # ── New schemas (not in batch 1) ──────────────────────────────────────

  # ── 1. Analytics.Benchmark ───────────────────────────────────────────
  # required: [:name, :benchmark_type]
  # inclusions: benchmark_type in ~w(index custom peer_group)

  describe "Analytics.Benchmark changeset" do
    alias Holdco.Analytics.Benchmark

    @valid_attrs %{name: "S&P 500", benchmark_type: "index"}

    test "valid changeset with all required fields" do
      changeset = Benchmark.changeset(%Benchmark{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          description: "Standard & Poor's 500 Index",
          ticker: "SPX",
          data_points: %{"2024" => 5000},
          is_active: false
        })

      changeset = Benchmark.changeset(%Benchmark{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing required name" do
      changeset = Benchmark.changeset(%Benchmark{}, %{benchmark_type: "index"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset missing required benchmark_type" do
      changeset = Benchmark.changeset(%Benchmark{}, %{name: "Test"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).benchmark_type
    end

    test "invalid changeset missing all required fields" do
      changeset = Benchmark.changeset(%Benchmark{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).benchmark_type
    end

    test "invalid changeset with bad benchmark_type inclusion" do
      attrs = %{name: "Test", benchmark_type: "invalid_type"}
      changeset = Benchmark.changeset(%Benchmark{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).benchmark_type
    end

    test "accepts each valid benchmark_type" do
      for type <- ~w(index custom peer_group) do
        changeset = Benchmark.changeset(%Benchmark{}, %{name: "B", benchmark_type: type})
        assert changeset.valid?, "expected #{type} to be valid"
      end
    end

    test "benchmark_types/0 returns expected list" do
      assert Benchmark.benchmark_types() == ~w(index custom peer_group)
    end
  end

  # ── 2. Analytics.BiExportLog ─────────────────────────────────────────
  # required: [:connector_id, :status]
  # inclusions: status in ~w(success partial failed)

  describe "Analytics.BiExportLog changeset" do
    alias Holdco.Analytics.BiExportLog

    @valid_attrs %{connector_id: 1, status: "success"}

    test "valid changeset with required fields" do
      changeset = BiExportLog.changeset(%BiExportLog{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          started_at: ~U[2024-01-01 00:00:00Z],
          completed_at: ~U[2024-01-01 01:00:00Z],
          rows_exported: 5000,
          tables_exported: ["companies", "transactions"],
          error_message: nil,
          file_size_bytes: 1_048_576
        })

      changeset = BiExportLog.changeset(%BiExportLog{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = BiExportLog.changeset(%BiExportLog{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).connector_id
      assert "can't be blank" in errors_on(changeset).status
    end

    test "invalid changeset missing connector_id" do
      changeset = BiExportLog.changeset(%BiExportLog{}, %{status: "success"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).connector_id
    end

    test "invalid changeset with bad status inclusion" do
      attrs = %{connector_id: 1, status: "invalid"}
      changeset = BiExportLog.changeset(%BiExportLog{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "accepts each valid status" do
      for status <- ~w(success partial failed) do
        changeset = BiExportLog.changeset(%BiExportLog{}, %{connector_id: 1, status: status})
        assert changeset.valid?, "expected #{status} to be valid"
      end
    end

    test "statuses/0 returns expected list" do
      assert BiExportLog.statuses() == ~w(success partial failed)
    end
  end

  # ── 3. Analytics.HealthScore ─────────────────────────────────────────
  # required: [:company_id, :score_date, :overall_score]
  # inclusions: trend in ~w(improving stable declining)
  # validate_number on score fields 0..100

  describe "Analytics.HealthScore changeset" do
    alias Holdco.Analytics.HealthScore

    @valid_attrs %{company_id: 1, score_date: ~D[2024-06-30], overall_score: Decimal.new("85.0")}

    test "valid changeset with required fields" do
      changeset = HealthScore.changeset(%HealthScore{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all sub-scores" do
      attrs =
        Map.merge(@valid_attrs, %{
          liquidity_score: Decimal.new("70"),
          profitability_score: Decimal.new("80"),
          compliance_score: Decimal.new("90"),
          governance_score: Decimal.new("85"),
          risk_score: Decimal.new("60"),
          operational_score: Decimal.new("75"),
          trend: "improving",
          notes: "Good overall health"
        })

      changeset = HealthScore.changeset(%HealthScore{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = HealthScore.changeset(%HealthScore{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).score_date
      assert "can't be blank" in errors_on(changeset).overall_score
    end

    test "invalid changeset with bad trend inclusion" do
      attrs = Map.merge(@valid_attrs, %{trend: "crashing"})
      changeset = HealthScore.changeset(%HealthScore{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).trend
    end

    test "accepts each valid trend" do
      for trend <- ~w(improving stable declining) do
        changeset = HealthScore.changeset(%HealthScore{}, Map.put(@valid_attrs, :trend, trend))
        assert changeset.valid?, "expected #{trend} to be valid"
      end
    end

    test "overall_score must be >= 0" do
      attrs = Map.put(@valid_attrs, :overall_score, Decimal.new("-1"))
      changeset = HealthScore.changeset(%HealthScore{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).overall_score
    end

    test "overall_score must be <= 100" do
      attrs = Map.put(@valid_attrs, :overall_score, Decimal.new("101"))
      changeset = HealthScore.changeset(%HealthScore{}, attrs)
      refute changeset.valid?
      assert "must be less than or equal to 100" in errors_on(changeset).overall_score
    end

    test "boundary: overall_score exactly 0 is valid" do
      attrs = Map.put(@valid_attrs, :overall_score, Decimal.new("0"))
      changeset = HealthScore.changeset(%HealthScore{}, attrs)
      assert changeset.valid?
    end

    test "boundary: overall_score exactly 100 is valid" do
      attrs = Map.put(@valid_attrs, :overall_score, Decimal.new("100"))
      changeset = HealthScore.changeset(%HealthScore{}, attrs)
      assert changeset.valid?
    end

    test "sub-scores reject values above 100" do
      for field <- [:liquidity_score, :profitability_score, :compliance_score, :governance_score, :risk_score, :operational_score] do
        attrs = Map.put(@valid_attrs, field, Decimal.new("101"))
        changeset = HealthScore.changeset(%HealthScore{}, attrs)
        refute changeset.valid?, "expected #{field} > 100 to be invalid"
        assert "must be less than or equal to 100" in errors_on(changeset)[field]
      end
    end

    test "sub-scores reject values below 0" do
      for field <- [:liquidity_score, :profitability_score, :compliance_score, :governance_score, :risk_score, :operational_score] do
        attrs = Map.put(@valid_attrs, field, Decimal.new("-1"))
        changeset = HealthScore.changeset(%HealthScore{}, attrs)
        refute changeset.valid?, "expected #{field} < 0 to be invalid"
        assert "must be greater than or equal to 0" in errors_on(changeset)[field]
      end
    end

    test "trends/0 returns expected list" do
      assert HealthScore.trends() == ~w(improving stable declining)
    end
  end

  # ── 4. Governance.FamilyCharter ──────────────────────────────────────
  # required: [:family_name, :version]
  # inclusions: status in ~w(draft active under_review archived)

  describe "Governance.FamilyCharter changeset" do
    alias Holdco.Governance.FamilyCharter

    @valid_attrs %{family_name: "Smith Family", version: "1.0"}

    test "valid changeset with required fields" do
      changeset = FamilyCharter.changeset(%FamilyCharter{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          status: "active",
          mission_statement: "Preserve and grow family wealth",
          values: ["integrity", "education"],
          decision_making_process: "Consensus",
          succession_plan: "Next generation to lead by 2030",
          education_policy: "Fund through graduate school",
          employment_policy: "Must work externally first",
          distribution_policy: "5% annual",
          conflict_resolution: "Mediation first",
          meeting_schedule: "Quarterly",
          next_review_date: ~D[2025-01-01],
          approved_by: ["John Smith", "Jane Smith"],
          approved_date: ~D[2024-01-15],
          notes: "Initial charter"
        })

      changeset = FamilyCharter.changeset(%FamilyCharter{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = FamilyCharter.changeset(%FamilyCharter{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).family_name
      assert "can't be blank" in errors_on(changeset).version
    end

    test "invalid changeset missing family_name" do
      changeset = FamilyCharter.changeset(%FamilyCharter{}, %{version: "1.0"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).family_name
    end

    test "invalid changeset with bad status inclusion" do
      attrs = Map.merge(@valid_attrs, %{status: "invalid"})
      changeset = FamilyCharter.changeset(%FamilyCharter{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "accepts each valid status" do
      for status <- ~w(draft active under_review archived) do
        changeset = FamilyCharter.changeset(%FamilyCharter{}, Map.put(@valid_attrs, :status, status))
        assert changeset.valid?, "expected #{status} to be valid"
      end
    end

    test "default status is draft" do
      changeset = FamilyCharter.changeset(%FamilyCharter{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "draft"
    end

    test "statuses/0 returns expected list" do
      assert FamilyCharter.statuses() == ~w(draft active under_review archived)
    end
  end

  # ── 5. Notifications.NotificationChannel ─────────────────────────────
  # required: [:user_id, :provider]
  # inclusions: provider in ~w(slack telegram email in_app)

  describe "Notifications.NotificationChannel changeset" do
    alias Holdco.Notifications.NotificationChannel

    @valid_attrs %{user_id: 1, provider: "slack"}

    test "valid changeset with required fields" do
      changeset = NotificationChannel.changeset(%NotificationChannel{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          is_active: true,
          config: %{"webhook_url" => "https://hooks.slack.com/..."},
          event_types: ["transaction_created", "alert_triggered"],
          notes: "Primary notification channel",
          name: "Main Slack",
          provider_type: "webhook",
          last_sent_at: ~U[2024-06-15 10:00:00Z],
          failure_count: 0
        })

      changeset = NotificationChannel.changeset(%NotificationChannel{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = NotificationChannel.changeset(%NotificationChannel{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).provider
    end

    test "invalid changeset missing user_id" do
      changeset = NotificationChannel.changeset(%NotificationChannel{}, %{provider: "email"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "invalid changeset with bad provider inclusion" do
      attrs = %{user_id: 1, provider: "invalid_provider"}
      changeset = NotificationChannel.changeset(%NotificationChannel{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).provider
    end

    test "accepts each valid provider" do
      for provider <- ~w(slack telegram email in_app) do
        changeset = NotificationChannel.changeset(%NotificationChannel{}, %{user_id: 1, provider: provider})
        assert changeset.valid?, "expected #{provider} to be valid"
      end
    end

    test "valid_providers/0 returns expected list" do
      assert NotificationChannel.valid_providers() == ~w(slack telegram email in_app)
    end
  end

  # ── 6. Notifications.NotificationLog ─────────────────────────────────
  # required: [:channel_id, :event_type, :message]
  # inclusions: status in ~w(sent failed pending)

  describe "Notifications.NotificationLog changeset" do
    alias Holdco.Notifications.NotificationLog

    @valid_attrs %{channel_id: 1, event_type: "alert_triggered", message: "New AML alert detected"}

    test "valid changeset with required fields" do
      changeset = NotificationLog.changeset(%NotificationLog{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          status: "sent",
          error_message: nil,
          sent_at: ~U[2024-06-15 10:30:00Z]
        })

      changeset = NotificationLog.changeset(%NotificationLog{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = NotificationLog.changeset(%NotificationLog{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).channel_id
      assert "can't be blank" in errors_on(changeset).event_type
      assert "can't be blank" in errors_on(changeset).message
    end

    test "invalid changeset missing message" do
      changeset = NotificationLog.changeset(%NotificationLog{}, %{channel_id: 1, event_type: "test"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).message
    end

    test "invalid changeset with bad status inclusion" do
      attrs = Map.merge(@valid_attrs, %{status: "dropped"})
      changeset = NotificationLog.changeset(%NotificationLog{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "accepts each valid status" do
      for status <- ~w(sent failed pending) do
        changeset = NotificationLog.changeset(%NotificationLog{}, Map.put(@valid_attrs, :status, status))
        assert changeset.valid?, "expected #{status} to be valid"
      end
    end

    test "default status is pending" do
      changeset = NotificationLog.changeset(%NotificationLog{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "statuses/0 returns expected list" do
      assert NotificationLog.statuses() == ~w(sent failed pending)
    end
  end

  # ── 7. Platform.ActivityEvent ────────────────────────────────────────
  # required: [:action, :entity_type]
  # inclusions: action in ~w(created updated deleted approved rejected locked unlocked exported imported dispatched)

  describe "Platform.ActivityEvent changeset" do
    alias Holdco.Platform.ActivityEvent

    @valid_attrs %{action: "created", entity_type: "transaction"}

    test "valid changeset with required fields" do
      changeset = ActivityEvent.changeset(%ActivityEvent{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          actor_id: 1,
          actor_email: "admin@example.com",
          entity_id: 42,
          entity_name: "Q4 Payment",
          context_module: "Finance.Transaction",
          metadata: %{"previous_status" => "pending"},
          company_id: 1,
          ip_address: "192.168.1.1",
          user_agent: "Mozilla/5.0"
        })

      changeset = ActivityEvent.changeset(%ActivityEvent{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = ActivityEvent.changeset(%ActivityEvent{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).action
      assert "can't be blank" in errors_on(changeset).entity_type
    end

    test "invalid changeset missing action" do
      changeset = ActivityEvent.changeset(%ActivityEvent{}, %{entity_type: "transaction"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).action
    end

    test "invalid changeset with bad action inclusion" do
      attrs = %{action: "unknown_action", entity_type: "transaction"}
      changeset = ActivityEvent.changeset(%ActivityEvent{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).action
    end

    test "accepts each valid action" do
      for action <- ~w(created updated deleted approved rejected locked unlocked exported imported dispatched) do
        changeset = ActivityEvent.changeset(%ActivityEvent{}, %{action: action, entity_type: "x"})
        assert changeset.valid?, "expected #{action} to be valid"
      end
    end

    test "actions/0 returns expected list" do
      assert ActivityEvent.actions() == ~w(created updated deleted approved rejected locked unlocked exported imported dispatched)
    end
  end

  # ── 8. Platform.PluginHook ──────────────────────────────────────────
  # required: [:plugin_id, :hook_point, :handler_function]
  # inclusions: hook_point in ~w(before_save after_save before_delete after_delete on_event scheduled)

  describe "Platform.PluginHook changeset" do
    alias Holdco.Platform.PluginHook

    @valid_attrs %{plugin_id: 1, hook_point: "before_save", handler_function: "MyPlugin.on_save/2"}

    test "valid changeset with required fields" do
      changeset = PluginHook.changeset(%PluginHook{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          entity_type: "transaction",
          priority: 10,
          is_active: false
        })

      changeset = PluginHook.changeset(%PluginHook{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = PluginHook.changeset(%PluginHook{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).plugin_id
      assert "can't be blank" in errors_on(changeset).hook_point
      assert "can't be blank" in errors_on(changeset).handler_function
    end

    test "invalid changeset missing handler_function" do
      changeset = PluginHook.changeset(%PluginHook{}, %{plugin_id: 1, hook_point: "on_event"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).handler_function
    end

    test "invalid changeset with bad hook_point inclusion" do
      attrs = %{plugin_id: 1, hook_point: "invalid_hook", handler_function: "f/0"}
      changeset = PluginHook.changeset(%PluginHook{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).hook_point
    end

    test "accepts each valid hook_point" do
      for hook <- ~w(before_save after_save before_delete after_delete on_event scheduled) do
        changeset = PluginHook.changeset(%PluginHook{}, %{plugin_id: 1, hook_point: hook, handler_function: "f/0"})
        assert changeset.valid?, "expected #{hook} to be valid"
      end
    end

    test "default priority is 50" do
      changeset = PluginHook.changeset(%PluginHook{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :priority) == 50
    end

    test "hook_points/0 returns expected list" do
      assert PluginHook.hook_points() == ~w(before_save after_save before_delete after_delete on_event scheduled)
    end
  end

  # ── 9. Platform.WebhookDelivery ─────────────────────────────────────
  # required: [:endpoint_id, :event_type]
  # inclusions: status in ~w(pending delivered failed retrying)

  describe "Platform.WebhookDelivery changeset" do
    alias Holdco.Platform.WebhookDelivery

    @valid_attrs %{endpoint_id: 1, event_type: "transaction.created"}

    test "valid changeset with required fields" do
      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          payload: %{"id" => 42, "type" => "transaction"},
          response_code: 200,
          response_body: "OK",
          status: "delivered",
          attempts: 1,
          next_retry_at: ~U[2024-06-15 11:00:00Z],
          delivered_at: ~U[2024-06-15 10:30:00Z]
        })

      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing all required fields" do
      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).endpoint_id
      assert "can't be blank" in errors_on(changeset).event_type
    end

    test "invalid changeset missing endpoint_id" do
      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, %{event_type: "test"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).endpoint_id
    end

    test "invalid changeset with bad status inclusion" do
      attrs = Map.merge(@valid_attrs, %{status: "unknown"})
      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "accepts each valid status" do
      for status <- ~w(pending delivered failed retrying) do
        changeset = WebhookDelivery.changeset(%WebhookDelivery{}, Map.put(@valid_attrs, :status, status))
        assert changeset.valid?, "expected #{status} to be valid"
      end
    end

    test "default status is pending" do
      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "default attempts is 0" do
      changeset = WebhookDelivery.changeset(%WebhookDelivery{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :attempts) == 0
    end

    test "statuses/0 returns expected list" do
      assert WebhookDelivery.statuses() == ~w(pending delivered failed retrying)
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # Additional edge-case tests for schemas already in batch 1
  # These exercise paths not covered by the 3 tests per schema in batch 1
  # ══════════════════════════════════════════════════════════════════════

  # ── 10. Analytics.Anomaly (extended) ─────────────────────────────────

  describe "Analytics.Anomaly edge cases" do
    alias Holdco.Analytics.Anomaly

    @valid_attrs %{entity_type: "transaction", anomaly_type: "outlier"}

    test "accepts each valid entity_type" do
      for et <- ~w(transaction financial holding bank_account) do
        changeset = Anomaly.changeset(%Anomaly{}, %{entity_type: et, anomaly_type: "outlier"})
        assert changeset.valid?, "expected entity_type #{et} to be valid"
      end
    end

    test "accepts each valid anomaly_type" do
      for at <- ~w(outlier duplicate unusual_amount unusual_frequency rapid_change) do
        changeset = Anomaly.changeset(%Anomaly{}, %{entity_type: "transaction", anomaly_type: at})
        assert changeset.valid?, "expected anomaly_type #{at} to be valid"
      end
    end

    test "accepts each valid severity" do
      for sev <- ~w(low medium high critical) do
        changeset = Anomaly.changeset(%Anomaly{}, Map.put(@valid_attrs, :severity, sev))
        assert changeset.valid?, "expected severity #{sev} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(open investigating resolved false_positive) do
        changeset = Anomaly.changeset(%Anomaly{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "valid changeset with all optional fields filled" do
      attrs =
        Map.merge(@valid_attrs, %{
          company_id: 1,
          entity_id: 42,
          severity: "high",
          description: "Large outlier detected",
          detected_value: Decimal.new("999999"),
          expected_range_low: Decimal.new("100"),
          expected_range_high: Decimal.new("1000"),
          deviation_pct: Decimal.new("99.9"),
          status: "investigating",
          resolved_at: ~U[2024-12-01 00:00:00Z],
          resolved_by_id: 2,
          notes: "Needs review"
        })

      changeset = Anomaly.changeset(%Anomaly{}, attrs)
      assert changeset.valid?
    end

    test "default severity is medium" do
      changeset = Anomaly.changeset(%Anomaly{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :severity) == "medium"
    end

    test "default status is open" do
      changeset = Anomaly.changeset(%Anomaly{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "open"
    end

    test "entity_types/0 returns expected list" do
      assert Anomaly.entity_types() == ~w(transaction financial holding bank_account)
    end

    test "anomaly_types/0 returns expected list" do
      assert Anomaly.anomaly_types() == ~w(outlier duplicate unusual_amount unusual_frequency rapid_change)
    end

    test "severities/0 returns expected list" do
      assert Anomaly.severities() == ~w(low medium high critical)
    end

    test "statuses/0 returns expected list" do
      assert Anomaly.statuses() == ~w(open investigating resolved false_positive)
    end
  end

  # ── 11. Compliance.EmissionsRecord (extended) ────────────────────────

  describe "Compliance.EmissionsRecord edge cases" do
    alias Holdco.Compliance.EmissionsRecord

    @valid_attrs %{company_id: 1, reporting_year: 2024, scope: "scope_1", category: "energy"}

    test "accepts each valid scope" do
      for scope <- ~w(scope_1 scope_2 scope_3) do
        changeset = EmissionsRecord.changeset(%EmissionsRecord{}, Map.put(@valid_attrs, :scope, scope))
        assert changeset.valid?, "expected scope #{scope} to be valid"
      end
    end

    test "accepts each valid category" do
      for cat <- ~w(energy transport waste supply_chain other) do
        changeset = EmissionsRecord.changeset(%EmissionsRecord{}, Map.put(@valid_attrs, :category, cat))
        assert changeset.valid?, "expected category #{cat} to be valid"
      end
    end

    test "accepts each valid unit" do
      for unit <- ~w(tonnes_co2e kg_co2e mwh liters km) do
        changeset = EmissionsRecord.changeset(%EmissionsRecord{}, Map.put(@valid_attrs, :unit, unit))
        assert changeset.valid?, "expected unit #{unit} to be valid"
      end
    end

    test "accepts each valid verification_status" do
      for vs <- ~w(unverified self_assessed third_party_verified) do
        changeset = EmissionsRecord.changeset(%EmissionsRecord{}, Map.put(@valid_attrs, :verification_status, vs))
        assert changeset.valid?, "expected verification_status #{vs} to be valid"
      end
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          source_description: "Natural gas combustion",
          quantity: Decimal.new("1500.5"),
          unit: "tonnes_co2e",
          emission_factor: Decimal.new("2.3"),
          co2_equivalent: Decimal.new("3451.15"),
          methodology: "GHG Protocol",
          verification_status: "third_party_verified",
          notes: "Audited externally"
        })

      changeset = EmissionsRecord.changeset(%EmissionsRecord{}, attrs)
      assert changeset.valid?
    end

    test "scopes/0 returns expected list" do
      assert EmissionsRecord.scopes() == ~w(scope_1 scope_2 scope_3)
    end

    test "categories/0 returns expected list" do
      assert EmissionsRecord.categories() == ~w(energy transport waste supply_chain other)
    end
  end

  # ── 12. Compliance.KycRecord (extended) ──────────────────────────────

  describe "Compliance.KycRecord edge cases" do
    alias Holdco.Compliance.KycRecord

    @valid_attrs %{company_id: 1, entity_name: "John Doe", entity_type: "individual"}

    test "accepts each valid entity_type" do
      for et <- ~w(individual corporate trust fund) do
        changeset = KycRecord.changeset(%KycRecord{}, Map.put(@valid_attrs, :entity_type, et))
        assert changeset.valid?, "expected entity_type #{et} to be valid"
      end
    end

    test "accepts each valid risk_level" do
      for rl <- ~w(low medium high pep) do
        changeset = KycRecord.changeset(%KycRecord{}, Map.put(@valid_attrs, :risk_level, rl))
        assert changeset.valid?, "expected risk_level #{rl} to be valid"
      end
    end

    test "accepts each valid verification_status" do
      for vs <- ~w(not_started documents_requested under_review verified rejected expired) do
        changeset = KycRecord.changeset(%KycRecord{}, Map.put(@valid_attrs, :verification_status, vs))
        assert changeset.valid?, "expected verification_status #{vs} to be valid"
      end
    end

    test "accepts each valid id_type" do
      for idt <- ~w(passport national_id drivers_license corporate_registration) do
        changeset = KycRecord.changeset(%KycRecord{}, Map.put(@valid_attrs, :id_type, idt))
        assert changeset.valid?, "expected id_type #{idt} to be valid"
      end
    end

    test "id_type allows nil" do
      changeset = KycRecord.changeset(%KycRecord{}, Map.put(@valid_attrs, :id_type, nil))
      assert changeset.valid?
    end

    test "invalid id_type is rejected" do
      changeset = KycRecord.changeset(%KycRecord{}, Map.put(@valid_attrs, :id_type, "invalid"))
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).id_type
    end

    test "valid changeset with full detail" do
      attrs =
        Map.merge(@valid_attrs, %{
          risk_level: "high",
          verification_status: "verified",
          id_type: "passport",
          id_number: "AB1234567",
          id_expiry_date: ~D[2030-12-31],
          country_of_residence: "US",
          nationality: "US",
          pep_status: true,
          sanctions_checked: true,
          last_review_date: ~D[2024-01-01],
          next_review_date: ~D[2025-01-01],
          reviewer_notes: "All clear",
          documents: ["passport_scan.pdf", "utility_bill.pdf"]
        })

      changeset = KycRecord.changeset(%KycRecord{}, attrs)
      assert changeset.valid?
    end

    test "entity_types/0 returns expected list" do
      assert KycRecord.entity_types() == ~w(individual corporate trust fund)
    end
  end

  # ── 13. Governance.EthicsReport (extended) ───────────────────────────

  describe "Governance.EthicsReport edge cases" do
    alias Holdco.Governance.EthicsReport

    @valid_attrs %{
      company_id: 1,
      report_type: "whistleblower",
      reporter_type: "anonymous",
      severity: "medium",
      description: "Suspicious activity observed",
      reported_date: ~D[2024-06-01]
    }

    test "accepts each valid report_type" do
      for rt <- ~w(whistleblower ethics_violation harassment fraud conflict_of_interest data_breach other) do
        changeset = EthicsReport.changeset(%EthicsReport{}, Map.put(@valid_attrs, :report_type, rt))
        assert changeset.valid?, "expected report_type #{rt} to be valid"
      end
    end

    test "accepts each valid reporter_type" do
      for rt <- ~w(anonymous named_internal named_external) do
        changeset = EthicsReport.changeset(%EthicsReport{}, Map.put(@valid_attrs, :reporter_type, rt))
        assert changeset.valid?, "expected reporter_type #{rt} to be valid"
      end
    end

    test "accepts each valid severity" do
      for sev <- ~w(low medium high critical) do
        changeset = EthicsReport.changeset(%EthicsReport{}, Map.put(@valid_attrs, :severity, sev))
        assert changeset.valid?, "expected severity #{sev} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(received under_investigation escalated resolved dismissed) do
        changeset = EthicsReport.changeset(%EthicsReport{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "missing description is invalid" do
      attrs = Map.delete(@valid_attrs, :description)
      changeset = EthicsReport.changeset(%EthicsReport{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).description
    end

    test "missing reported_date is invalid" do
      attrs = Map.delete(@valid_attrs, :reported_date)
      changeset = EthicsReport.changeset(%EthicsReport{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).reported_date
    end

    test "report_types/0 returns expected list" do
      assert EthicsReport.report_types() == ~w(whistleblower ethics_violation harassment fraud conflict_of_interest data_breach other)
    end

    test "reporter_types/0 returns expected list" do
      assert EthicsReport.reporter_types() == ~w(anonymous named_internal named_external)
    end
  end

  # ── 14. Analytics.BiConnector (extended) ─────────────────────────────

  describe "Analytics.BiConnector edge cases" do
    alias Holdco.Analytics.BiConnector

    @valid_attrs %{name: "My Tableau", connector_type: "tableau"}

    test "accepts each valid connector_type" do
      for ct <- ~w(power_bi tableau looker metabase custom) do
        changeset = BiConnector.changeset(%BiConnector{}, %{name: "C", connector_type: ct})
        assert changeset.valid?, "expected connector_type #{ct} to be valid"
      end
    end

    test "accepts each valid refresh_frequency" do
      for rf <- ~w(manual hourly daily weekly) do
        changeset = BiConnector.changeset(%BiConnector{}, Map.put(@valid_attrs, :refresh_frequency, rf))
        assert changeset.valid?, "expected refresh_frequency #{rf} to be valid"
      end
    end

    test "accepts each valid sync_status" do
      for ss <- ~w(idle syncing error completed) do
        changeset = BiConnector.changeset(%BiConnector{}, Map.put(@valid_attrs, :sync_status, ss))
        assert changeset.valid?, "expected sync_status #{ss} to be valid"
      end
    end

    test "invalid refresh_frequency is rejected" do
      attrs = Map.put(@valid_attrs, :refresh_frequency, "every_minute")
      changeset = BiConnector.changeset(%BiConnector{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).refresh_frequency
    end

    test "invalid sync_status is rejected" do
      attrs = Map.put(@valid_attrs, :sync_status, "broken")
      changeset = BiConnector.changeset(%BiConnector{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).sync_status
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          connection_string_encrypted: "enc_abc123",
          api_key_encrypted: "enc_key456",
          dataset_name: "holdco_data",
          refresh_frequency: "daily",
          last_sync_at: ~U[2024-06-15 00:00:00Z],
          sync_status: "completed",
          tables_included: ["companies", "transactions", "holdings"],
          row_limit: 100_000,
          format: "csv",
          is_active: true,
          error_log: nil,
          notes: "Production connector"
        })

      changeset = BiConnector.changeset(%BiConnector{}, attrs)
      assert changeset.valid?
    end

    test "connector_types/0 returns expected list" do
      assert BiConnector.connector_types() == ~w(power_bi tableau looker metabase custom)
    end

    test "refresh_frequencies/0 returns expected list" do
      assert BiConnector.refresh_frequencies() == ~w(manual hourly daily weekly)
    end
  end

  # ── 15. Compliance.AmlAlert (extended) ───────────────────────────────

  describe "Compliance.AmlAlert edge cases" do
    alias Holdco.Compliance.AmlAlert

    @valid_attrs %{company_id: 1, alert_type: "large_transaction", severity: "medium"}

    test "accepts each valid alert_type" do
      for at <- ~w(large_transaction structuring velocity geographic_risk pattern_match pep_related) do
        changeset = AmlAlert.changeset(%AmlAlert{}, Map.put(@valid_attrs, :alert_type, at))
        assert changeset.valid?, "expected alert_type #{at} to be valid"
      end
    end

    test "accepts each valid severity" do
      for sev <- ~w(low medium high critical) do
        changeset = AmlAlert.changeset(%AmlAlert{}, Map.put(@valid_attrs, :severity, sev))
        assert changeset.valid?, "expected severity #{sev} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(open investigating escalated filed_sar dismissed) do
        changeset = AmlAlert.changeset(%AmlAlert{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          transaction_id: "TXN-12345",
          amount: Decimal.new("50000"),
          currency: "EUR",
          description: "Multiple large transfers",
          rule_triggered: "threshold_exceeded",
          status: "investigating",
          assigned_to: "compliance_officer@example.com",
          resolution_notes: "Reviewing documents",
          resolved_at: ~U[2024-06-20 14:00:00Z]
        })

      changeset = AmlAlert.changeset(%AmlAlert{}, attrs)
      assert changeset.valid?
    end

    test "alert_types/0 returns expected list" do
      assert AmlAlert.alert_types() == ~w(large_transaction structuring velocity geographic_risk pattern_match pep_related)
    end

    test "severities/0 returns expected list" do
      assert AmlAlert.severities() == ~w(low medium high critical)
    end
  end

  # ── 16. Compliance.BcpPlan (extended) ────────────────────────────────

  describe "Compliance.BcpPlan edge cases" do
    alias Holdco.Compliance.BcpPlan

    @valid_attrs %{company_id: 1, plan_name: "DR Plan 2024", plan_type: "disaster_recovery"}

    test "accepts each valid plan_type" do
      for pt <- ~w(disaster_recovery business_continuity pandemic cyber_incident financial_crisis) do
        changeset = BcpPlan.changeset(%BcpPlan{}, Map.put(@valid_attrs, :plan_type, pt))
        assert changeset.valid?, "expected plan_type #{pt} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(draft approved active under_review retired) do
        changeset = BcpPlan.changeset(%BcpPlan{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "accepts each valid test_result" do
      for tr <- ~w(passed partial failed not_tested) do
        changeset = BcpPlan.changeset(%BcpPlan{}, Map.put(@valid_attrs, :test_result, tr))
        assert changeset.valid?, "expected test_result #{tr} to be valid"
      end
    end

    test "invalid test_result is rejected" do
      attrs = Map.put(@valid_attrs, :test_result, "inconclusive")
      changeset = BcpPlan.changeset(%BcpPlan{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).test_result
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          version: "2.1",
          status: "approved",
          approved_by: "CTO",
          approved_date: ~D[2024-01-15],
          last_tested_date: ~D[2024-03-01],
          next_test_date: ~D[2024-09-01],
          test_result: "passed",
          rto_hours: 4,
          rpo_hours: 1,
          key_contacts: [%{"name" => "CTO", "phone" => "555-0100"}],
          critical_systems: ["database", "payments", "auth"],
          notes: "Annual review complete"
        })

      changeset = BcpPlan.changeset(%BcpPlan{}, attrs)
      assert changeset.valid?
    end

    test "plan_types/0 returns expected list" do
      assert BcpPlan.plan_types() == ~w(disaster_recovery business_continuity pandemic cyber_incident financial_crisis)
    end
  end

  # ── 17. Compliance.Litigation (extended) ─────────────────────────────

  describe "Compliance.Litigation edge cases" do
    alias Holdco.Compliance.Litigation

    @valid_attrs %{company_id: 1, case_name: "Smith v. Holdco", case_type: "civil", party_role: "defendant"}

    test "accepts each valid case_type" do
      for ct <- ~w(civil criminal regulatory arbitration mediation administrative) do
        changeset = Litigation.changeset(%Litigation{}, Map.put(@valid_attrs, :case_type, ct))
        assert changeset.valid?, "expected case_type #{ct} to be valid"
      end
    end

    test "accepts each valid party_role" do
      for pr <- ~w(plaintiff defendant respondent petitioner) do
        changeset = Litigation.changeset(%Litigation{}, Map.put(@valid_attrs, :party_role, pr))
        assert changeset.valid?, "expected party_role #{pr} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(pre_filing active discovery trial appeal settled dismissed closed) do
        changeset = Litigation.changeset(%Litigation{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "estimated_exposure must be >= 0" do
      attrs = Map.put(@valid_attrs, :estimated_exposure, Decimal.new("-100"))
      changeset = Litigation.changeset(%Litigation{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).estimated_exposure
    end

    test "estimated_exposure allows zero" do
      attrs = Map.put(@valid_attrs, :estimated_exposure, Decimal.new("0"))
      changeset = Litigation.changeset(%Litigation{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          case_number: "2024-CV-001",
          court_or_tribunal: "District Court",
          jurisdiction: "Delaware",
          opposing_party: "Smith Corp",
          filing_date: ~D[2024-01-15],
          status: "discovery",
          estimated_exposure: Decimal.new("500000"),
          actual_outcome_amount: nil,
          currency: "USD",
          lead_counsel: "Jane Attorney",
          next_hearing_date: ~D[2024-09-01],
          notes: "Initial phase"
        })

      changeset = Litigation.changeset(%Litigation{}, attrs)
      assert changeset.valid?
    end

    test "case_types/0 returns expected list" do
      assert Litigation.case_types() == ~w(civil criminal regulatory arbitration mediation administrative)
    end
  end

  # ── 18. Finance.CompensationRecord (extended) ────────────────────────

  describe "Finance.CompensationRecord edge cases" do
    alias Holdco.Finance.CompensationRecord

    @valid_attrs %{
      company_id: 1,
      employee_name: "Alice",
      compensation_type: "salary",
      amount: Decimal.new("120000"),
      frequency: "annual"
    }

    test "accepts each valid compensation_type" do
      for ct <- ~w(salary bonus equity commission benefit severance) do
        changeset = CompensationRecord.changeset(%CompensationRecord{}, Map.put(@valid_attrs, :compensation_type, ct))
        assert changeset.valid?, "expected compensation_type #{ct} to be valid"
      end
    end

    test "accepts each valid frequency" do
      for f <- ~w(monthly quarterly annual one_time) do
        changeset = CompensationRecord.changeset(%CompensationRecord{}, Map.put(@valid_attrs, :frequency, f))
        assert changeset.valid?, "expected frequency #{f} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(active pending terminated) do
        changeset = CompensationRecord.changeset(%CompensationRecord{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "amount must be greater than 0" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("0"))
      changeset = CompensationRecord.changeset(%CompensationRecord{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "negative amount is invalid" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("-50"))
      changeset = CompensationRecord.changeset(%CompensationRecord{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          role: "VP Engineering",
          department: "Engineering",
          currency: "EUR",
          effective_date: ~D[2024-01-01],
          end_date: ~D[2024-12-31],
          vesting_schedule: "4 years with 1 year cliff",
          status: "active",
          notes: "Annual review"
        })

      changeset = CompensationRecord.changeset(%CompensationRecord{}, attrs)
      assert changeset.valid?
    end

    test "compensation_types/0 returns expected list" do
      assert CompensationRecord.compensation_types() == ~w(salary bonus equity commission benefit severance)
    end

    test "frequencies/0 returns expected list" do
      assert CompensationRecord.frequencies() == ~w(monthly quarterly annual one_time)
    end
  end

  # ── 19. Finance.TrustAccount (extended) ──────────────────────────────

  describe "Finance.TrustAccount edge cases" do
    alias Holdco.Finance.TrustAccount

    @valid_attrs %{company_id: 1, trust_name: "Family Trust", trust_type: "revocable", trustee_name: "Bank of Trust"}

    test "accepts each valid trust_type" do
      for tt <- ~w(revocable irrevocable testamentary charitable special_needs grantor_retained) do
        changeset = TrustAccount.changeset(%TrustAccount{}, Map.put(@valid_attrs, :trust_type, tt))
        assert changeset.valid?, "expected trust_type #{tt} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(active terminated pending suspended) do
        changeset = TrustAccount.changeset(%TrustAccount{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "accepts each valid distribution_schedule" do
      for ds <- ~w(monthly quarterly annually discretionary) do
        changeset = TrustAccount.changeset(%TrustAccount{}, Map.put(@valid_attrs, :distribution_schedule, ds))
        assert changeset.valid?, "expected distribution_schedule #{ds} to be valid"
      end
    end

    test "corpus_value must be >= 0" do
      attrs = Map.put(@valid_attrs, :corpus_value, Decimal.new("-1"))
      changeset = TrustAccount.changeset(%TrustAccount{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).corpus_value
    end

    test "corpus_value allows zero" do
      attrs = Map.put(@valid_attrs, :corpus_value, Decimal.new("0"))
      changeset = TrustAccount.changeset(%TrustAccount{}, attrs)
      assert changeset.valid?
    end

    test "missing trustee_name is invalid" do
      attrs = Map.delete(@valid_attrs, :trustee_name)
      changeset = TrustAccount.changeset(%TrustAccount{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).trustee_name
    end

    test "trust_types/0 returns expected list" do
      assert TrustAccount.trust_types() == ~w(revocable irrevocable testamentary charitable special_needs grantor_retained)
    end
  end

  # ── 20. Governance.ConflictOfInterest (extended) ─────────────────────

  describe "Governance.ConflictOfInterest edge cases" do
    alias Holdco.Governance.ConflictOfInterest

    @valid_attrs %{
      company_id: 1,
      declarant_name: "John Smith",
      declarant_role: "director",
      conflict_type: "financial",
      description: "Board member has shares in vendor",
      declared_date: ~D[2024-03-01]
    }

    test "accepts each valid declarant_role" do
      for dr <- ~w(director officer employee advisor) do
        changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, Map.put(@valid_attrs, :declarant_role, dr))
        assert changeset.valid?, "expected declarant_role #{dr} to be valid"
      end
    end

    test "accepts each valid conflict_type" do
      for ct <- ~w(financial personal professional organizational) do
        changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, Map.put(@valid_attrs, :conflict_type, ct))
        assert changeset.valid?, "expected conflict_type #{ct} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(declared under_review approved mitigated ongoing resolved) do
        changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "missing declared_date is invalid" do
      attrs = Map.delete(@valid_attrs, :declared_date)
      changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).declared_date
    end

    test "missing description is invalid" do
      attrs = Map.delete(@valid_attrs, :description)
      changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).description
    end

    test "declarant_roles/0 returns expected list" do
      assert ConflictOfInterest.declarant_roles() == ~w(director officer employee advisor)
    end

    test "conflict_types/0 returns expected list" do
      assert ConflictOfInterest.conflict_types() == ~w(financial personal professional organizational)
    end
  end

  # ── 21. Analytics.Airdrop (extended) ─────────────────────────────────

  describe "Analytics.Airdrop edge cases" do
    alias Holdco.Analytics.Airdrop

    @valid_attrs %{company_id: 1, event_type: "airdrop", token_name: "UNI", chain: "ethereum"}

    test "accepts each valid event_type" do
      for et <- ~w(airdrop fork token_split migration) do
        changeset = Airdrop.changeset(%Airdrop{}, Map.put(@valid_attrs, :event_type, et))
        assert changeset.valid?, "expected event_type #{et} to be valid"
      end
    end

    test "accepts each valid chain" do
      for chain <- ~w(ethereum polygon arbitrum solana avalanche bsc other) do
        changeset = Airdrop.changeset(%Airdrop{}, Map.put(@valid_attrs, :chain, chain))
        assert changeset.valid?, "expected chain #{chain} to be valid"
      end
    end

    test "invalid event_type is rejected" do
      attrs = Map.put(@valid_attrs, :event_type, "rug_pull")
      changeset = Airdrop.changeset(%Airdrop{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).event_type
    end

    test "invalid chain is rejected" do
      attrs = Map.put(@valid_attrs, :chain, "bitcoin")
      changeset = Airdrop.changeset(%Airdrop{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).chain
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          amount: Decimal.new("1000"),
          value_at_receipt: Decimal.new("5000"),
          current_value: Decimal.new("4500"),
          currency: "USD",
          wallet_address: "0xabc123",
          received_date: ~D[2024-01-15],
          claimed: true,
          claimed_date: ~D[2024-01-20],
          eligible: true,
          snapshot_date: ~D[2024-01-01],
          tax_treated: false,
          notes: "Governance token airdrop"
        })

      changeset = Airdrop.changeset(%Airdrop{}, attrs)
      assert changeset.valid?
    end

    test "event_types/0 returns expected list" do
      assert Airdrop.event_types() == ~w(airdrop fork token_split migration)
    end

    test "chains/0 returns expected list" do
      assert Airdrop.chains() == ~w(ethereum polygon arbitrum solana avalanche bsc other)
    end
  end

  # ── 22. Compliance.EsgReport (extended) ──────────────────────────────

  describe "Compliance.EsgReport edge cases" do
    alias Holdco.Compliance.EsgReport

    @valid_attrs %{
      company_id: 1,
      framework: "gri",
      reporting_period_start: ~D[2024-01-01],
      reporting_period_end: ~D[2024-12-31],
      title: "Annual ESG Report 2024"
    }

    test "accepts each valid framework" do
      for fw <- ~w(gri sasb tcfd custom) do
        changeset = EsgReport.changeset(%EsgReport{}, Map.put(@valid_attrs, :framework, fw))
        assert changeset.valid?, "expected framework #{fw} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(draft under_review published) do
        changeset = EsgReport.changeset(%EsgReport{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "missing title is invalid" do
      attrs = Map.delete(@valid_attrs, :title)
      changeset = EsgReport.changeset(%EsgReport{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "missing reporting_period_start is invalid" do
      attrs = Map.delete(@valid_attrs, :reporting_period_start)
      changeset = EsgReport.changeset(%EsgReport{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).reporting_period_start
    end

    test "missing reporting_period_end is invalid" do
      attrs = Map.delete(@valid_attrs, :reporting_period_end)
      changeset = EsgReport.changeset(%EsgReport{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).reporting_period_end
    end

    test "frameworks/0 returns expected list" do
      assert EsgReport.frameworks() == ~w(gri sasb tcfd custom)
    end

    test "statuses/0 returns expected list" do
      assert EsgReport.statuses() == ~w(draft under_review published)
    end
  end

  # ── 23. Compliance.InsuranceClaim (extended) ─────────────────────────

  describe "Compliance.InsuranceClaim edge cases" do
    alias Holdco.Compliance.InsuranceClaim

    @valid_attrs %{company_id: 1, claim_number: "CLM-2024-001", claim_type: "property"}

    test "accepts each valid claim_type" do
      for ct <- ~w(property liability professional cyber directors_officers workers_comp other) do
        changeset = InsuranceClaim.changeset(%InsuranceClaim{}, Map.put(@valid_attrs, :claim_type, ct))
        assert changeset.valid?, "expected claim_type #{ct} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(filed under_review approved denied settled closed) do
        changeset = InsuranceClaim.changeset(%InsuranceClaim{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "claimed_amount must be >= 0" do
      attrs = Map.put(@valid_attrs, :claimed_amount, Decimal.new("-100"))
      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).claimed_amount
    end

    test "settled_amount must be >= 0" do
      attrs = Map.put(@valid_attrs, :settled_amount, Decimal.new("-50"))
      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).settled_amount
    end

    test "deductible must be >= 0" do
      attrs = Map.put(@valid_attrs, :deductible, Decimal.new("-1"))
      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).deductible
    end

    test "zero amounts are valid" do
      attrs =
        Map.merge(@valid_attrs, %{
          claimed_amount: Decimal.new("0"),
          settled_amount: Decimal.new("0"),
          deductible: Decimal.new("0")
        })

      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          policy_id: 1,
          incident_date: ~D[2024-03-01],
          filing_date: ~D[2024-03-15],
          description: "Water damage in server room",
          claimed_amount: Decimal.new("50000"),
          settled_amount: Decimal.new("45000"),
          deductible: Decimal.new("5000"),
          status: "settled",
          adjuster_name: "Bob Adjuster",
          adjuster_contact: "bob@insurance.com",
          settlement_date: ~D[2024-06-01],
          notes: "Settled below claimed"
        })

      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, attrs)
      assert changeset.valid?
    end

    test "claim_types/0 returns expected list" do
      assert InsuranceClaim.claim_types() == ~w(property liability professional cyber directors_officers workers_comp other)
    end
  end

  # ── 24. Compliance.RegulatoryCapital (extended) ──────────────────────

  describe "Compliance.RegulatoryCapital edge cases" do
    alias Holdco.Compliance.RegulatoryCapital

    @valid_attrs %{company_id: 1, reporting_date: ~D[2024-06-30], framework: "basel_iii"}

    test "accepts each valid framework" do
      for fw <- ~w(basel_iii solvency_ii mifid_ii dodd_frank custom) do
        changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, Map.put(@valid_attrs, :framework, fw))
        assert changeset.valid?, "expected framework #{fw} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(compliant warning breach) do
        changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid framework is rejected" do
      attrs = Map.put(@valid_attrs, :framework, "unknown")
      changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).framework
    end

    test "valid changeset with all financial fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          tier1_capital: Decimal.new("10000000"),
          tier2_capital: Decimal.new("5000000"),
          total_capital: Decimal.new("15000000"),
          risk_weighted_assets: Decimal.new("100000000"),
          capital_ratio: Decimal.new("15.0"),
          minimum_required_ratio: Decimal.new("8.0"),
          buffer_required: Decimal.new("2.5"),
          surplus_or_deficit: Decimal.new("4500000"),
          currency: "EUR",
          status: "compliant",
          notes: "Quarterly capital report"
        })

      changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, attrs)
      assert changeset.valid?
    end

    test "frameworks/0 returns expected list" do
      assert RegulatoryCapital.frameworks() == ~w(basel_iii solvency_ii mifid_ii dodd_frank custom)
    end

    test "statuses/0 returns expected list" do
      assert RegulatoryCapital.statuses() == ~w(compliant warning breach)
    end
  end

  # ── 25. Compliance.ReportingTemplate (extended) ──────────────────────

  describe "Compliance.ReportingTemplate edge cases" do
    alias Holdco.Compliance.ReportingTemplate

    @valid_attrs %{name: "CRS Annual", template_type: "crs", frequency: "annual"}

    test "accepts each valid template_type" do
      for tt <- ~w(crs fatca bo_register aml_report regulatory_return tax_return) do
        changeset = ReportingTemplate.changeset(%ReportingTemplate{}, Map.put(@valid_attrs, :template_type, tt))
        assert changeset.valid?, "expected template_type #{tt} to be valid"
      end
    end

    test "accepts each valid frequency" do
      for f <- ~w(annual semi_annual quarterly monthly ad_hoc) do
        changeset = ReportingTemplate.changeset(%ReportingTemplate{}, Map.put(@valid_attrs, :frequency, f))
        assert changeset.valid?, "expected frequency #{f} to be valid"
      end
    end

    test "invalid template_type is rejected" do
      attrs = Map.put(@valid_attrs, :template_type, "unknown")
      changeset = ReportingTemplate.changeset(%ReportingTemplate{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).template_type
    end

    test "invalid frequency is rejected" do
      attrs = Map.put(@valid_attrs, :frequency, "biweekly")
      changeset = ReportingTemplate.changeset(%ReportingTemplate{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).frequency
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          jurisdiction: "Luxembourg",
          due_date_formula: "T+90 days after year end",
          fields: %{"field1" => "string", "field2" => "decimal"},
          is_active: true,
          notes: "Standard CRS template"
        })

      changeset = ReportingTemplate.changeset(%ReportingTemplate{}, attrs)
      assert changeset.valid?
    end

    test "template_types/0 returns expected list" do
      assert ReportingTemplate.template_types() == ~w(crs fatca bo_register aml_report regulatory_return tax_return)
    end

    test "frequencies/0 returns expected list" do
      assert ReportingTemplate.frequencies() == ~w(annual semi_annual quarterly monthly ad_hoc)
    end
  end

  # ── 26. Corporate.EntityLifecycle (extended) ─────────────────────────

  describe "Corporate.EntityLifecycle edge cases" do
    alias Holdco.Corporate.EntityLifecycle

    @valid_attrs %{company_id: 1, event_type: "incorporation", event_date: "2024-01-15"}

    test "accepts each valid event_type" do
      for et <- ~w(incorporation registration amendment redomiciliation merger spin_off dissolution reinstatement name_change other) do
        changeset = EntityLifecycle.changeset(%EntityLifecycle{}, Map.put(@valid_attrs, :event_type, et))
        assert changeset.valid?, "expected event_type #{et} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(pending completed rejected) do
        changeset = EntityLifecycle.changeset(%EntityLifecycle{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid event_date format is rejected" do
      attrs = Map.put(@valid_attrs, :event_date, "not-a-date")
      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, attrs)
      refute changeset.valid?
      assert "must be a valid date (YYYY-MM-DD)" in errors_on(changeset).event_date
    end

    test "invalid effective_date format is rejected" do
      attrs = Map.put(@valid_attrs, :effective_date, "31/12/2024")
      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, attrs)
      refute changeset.valid?
      assert "must be a valid date (YYYY-MM-DD)" in errors_on(changeset).effective_date
    end

    test "valid ISO date formats accepted" do
      attrs = Map.merge(@valid_attrs, %{effective_date: "2024-12-31"})
      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          effective_date: "2024-02-01",
          jurisdiction: "Delaware",
          filing_reference: "DE-2024-0001",
          description: "Initial incorporation",
          status: "completed",
          documents: ["certificate_of_incorporation.pdf"],
          notes: "Filed with state"
        })

      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, attrs)
      assert changeset.valid?
    end

    test "event_types/0 returns expected list" do
      assert EntityLifecycle.event_types() == ~w(incorporation registration amendment redomiciliation merger spin_off dissolution reinstatement name_change other)
    end
  end

  # ── 27. Corporate.IpAsset (extended) ─────────────────────────────────

  describe "Corporate.IpAsset edge cases" do
    alias Holdco.Corporate.IpAsset

    @valid_attrs %{company_id: 1, name: "HoldcoOS", asset_type: "software_license"}

    test "accepts each valid asset_type" do
      for at <- ~w(patent trademark copyright trade_secret domain software_license) do
        changeset = IpAsset.changeset(%IpAsset{}, Map.put(@valid_attrs, :asset_type, at))
        assert changeset.valid?, "expected asset_type #{at} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(pending active expired abandoned transferred) do
        changeset = IpAsset.changeset(%IpAsset{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid asset_type is rejected" do
      attrs = Map.put(@valid_attrs, :asset_type, "nft")
      changeset = IpAsset.changeset(%IpAsset{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).asset_type
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          registration_number: "US-PAT-123456",
          jurisdiction: "US",
          filing_date: ~D[2023-06-01],
          grant_date: ~D[2024-01-15],
          expiry_date: ~D[2044-01-15],
          status: "active",
          owner_entity: "Holdco Inc.",
          licensees: ["SubCo A", "SubCo B"],
          annual_cost: Decimal.new("5000"),
          currency: "USD",
          valuation: Decimal.new("500000"),
          notes: "Core platform patent"
        })

      changeset = IpAsset.changeset(%IpAsset{}, attrs)
      assert changeset.valid?
    end

    test "asset_types/0 returns expected list" do
      assert IpAsset.asset_types() == ~w(patent trademark copyright trade_secret domain software_license)
    end
  end

  # ── 28. Corporate.LeiRecord (extended) ───────────────────────────────

  describe "Corporate.LeiRecord edge cases" do
    alias Holdco.Corporate.LeiRecord

    @valid_attrs %{company_id: 1, lei_code: "12345678901234567890"}

    test "accepts each valid registration_status" do
      for rs <- ~w(pending issued lapsed retired) do
        changeset = LeiRecord.changeset(%LeiRecord{}, Map.put(@valid_attrs, :registration_status, rs))
        assert changeset.valid?, "expected registration_status #{rs} to be valid"
      end
    end

    test "accepts each valid entity_status" do
      for es <- ~w(active inactive) do
        changeset = LeiRecord.changeset(%LeiRecord{}, Map.put(@valid_attrs, :entity_status, es))
        assert changeset.valid?, "expected entity_status #{es} to be valid"
      end
    end

    test "lei_code must be exactly 20 characters" do
      short = Map.put(@valid_attrs, :lei_code, "12345")
      changeset = LeiRecord.changeset(%LeiRecord{}, short)
      refute changeset.valid?
      assert "should be 20 character(s)" in errors_on(changeset).lei_code
    end

    test "lei_code too long is rejected" do
      long = Map.put(@valid_attrs, :lei_code, String.duplicate("A", 21))
      changeset = LeiRecord.changeset(%LeiRecord{}, long)
      refute changeset.valid?
      assert "should be 20 character(s)" in errors_on(changeset).lei_code
    end

    test "lei_code exactly 20 characters is valid" do
      changeset = LeiRecord.changeset(%LeiRecord{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          registration_status: "issued",
          initial_registration_date: ~D[2020-01-01],
          last_renewal_date: ~D[2024-01-01],
          next_renewal_date: ~D[2025-01-01],
          managing_lou: "BLOOMBERG",
          legal_name: "Holdco International LLC",
          jurisdiction: "Delaware",
          registration_authority: "DE Secretary of State",
          entity_status: "active",
          notes: "Annual renewal due"
        })

      changeset = LeiRecord.changeset(%LeiRecord{}, attrs)
      assert changeset.valid?
    end

    test "registration_statuses/0 returns expected list" do
      assert LeiRecord.registration_statuses() == ~w(pending issued lapsed retired)
    end

    test "entity_statuses/0 returns expected list" do
      assert LeiRecord.entity_statuses() == ~w(active inactive)
    end
  end

  # ── 29. Documents.DataRoom (extended) ────────────────────────────────

  describe "Documents.DataRoom edge cases" do
    alias Holdco.Documents.DataRoom

    @valid_attrs %{company_id: 1, name: "Series B Data Room"}

    test "accepts each valid access_level" do
      for al <- ~w(public restricted confidential) do
        changeset = DataRoom.changeset(%DataRoom{}, Map.put(@valid_attrs, :access_level, al))
        assert changeset.valid?, "expected access_level #{al} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(active archived expired) do
        changeset = DataRoom.changeset(%DataRoom{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid access_level is rejected" do
      attrs = Map.put(@valid_attrs, :access_level, "top_secret")
      changeset = DataRoom.changeset(%DataRoom{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).access_level
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          description: "Due diligence documents for Series B",
          access_level: "confidential",
          status: "active",
          created_by_id: 1,
          expires_at: ~U[2025-12-31 23:59:59Z],
          watermark_enabled: true,
          download_allowed: false,
          visitor_count: 15,
          notes: "Access restricted to investors"
        })

      changeset = DataRoom.changeset(%DataRoom{}, attrs)
      assert changeset.valid?
    end

    test "default access_level is restricted" do
      changeset = DataRoom.changeset(%DataRoom{}, @valid_attrs)
      assert Ecto.Changeset.get_field(changeset, :access_level) == "restricted"
    end

    test "access_levels/0 returns expected list" do
      assert DataRoom.access_levels() == ~w(public restricted confidential)
    end
  end

  # ── 30. Finance.BankGuarantee (extended) ─────────────────────────────

  describe "Finance.BankGuarantee edge cases" do
    alias Holdco.Finance.BankGuarantee

    @valid_attrs %{
      company_id: 1,
      guarantee_type: "performance",
      issuing_bank: "First Bank",
      beneficiary: "Vendor Corp",
      amount: Decimal.new("100000")
    }

    test "accepts each valid guarantee_type" do
      for gt <- ~w(performance financial bid advance_payment loc standby_loc) do
        changeset = BankGuarantee.changeset(%BankGuarantee{}, Map.put(@valid_attrs, :guarantee_type, gt))
        assert changeset.valid?, "expected guarantee_type #{gt} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(active expired called released renewed) do
        changeset = BankGuarantee.changeset(%BankGuarantee{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "amount must be greater than 0" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("0"))
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "negative amount is invalid" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("-500"))
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "annual_fee_pct must be >= 0" do
      attrs = Map.put(@valid_attrs, :annual_fee_pct, Decimal.new("-0.5"))
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).annual_fee_pct
    end

    test "annual_fee_pct zero is valid" do
      attrs = Map.put(@valid_attrs, :annual_fee_pct, Decimal.new("0"))
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      assert changeset.valid?
    end

    test "missing issuing_bank is invalid" do
      attrs = Map.delete(@valid_attrs, :issuing_bank)
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).issuing_bank
    end

    test "missing beneficiary is invalid" do
      attrs = Map.delete(@valid_attrs, :beneficiary)
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).beneficiary
    end

    test "guarantee_types/0 returns expected list" do
      assert BankGuarantee.guarantee_types() == ~w(performance financial bid advance_payment loc standby_loc)
    end
  end

  # ── 31. Finance.CharitableGift (extended) ────────────────────────────

  describe "Finance.CharitableGift edge cases" do
    alias Holdco.Finance.CharitableGift

    @valid_attrs %{
      company_id: 1,
      recipient_name: "Red Cross",
      amount: Decimal.new("10000"),
      gift_date: ~D[2024-12-15]
    }

    test "accepts each valid recipient_type" do
      for rt <- ~w(501c3 daf private_foundation public_charity religious educational other) do
        changeset = CharitableGift.changeset(%CharitableGift{}, Map.put(@valid_attrs, :recipient_type, rt))
        assert changeset.valid?, "expected recipient_type #{rt} to be valid"
      end
    end

    test "accepts each valid gift_type" do
      for gt <- ~w(cash securities property in_kind pledge) do
        changeset = CharitableGift.changeset(%CharitableGift{}, Map.put(@valid_attrs, :gift_type, gt))
        assert changeset.valid?, "expected gift_type #{gt} to be valid"
      end
    end

    test "amount must be greater than 0" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("0"))
      changeset = CharitableGift.changeset(%CharitableGift{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "negative amount is invalid" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("-100"))
      changeset = CharitableGift.changeset(%CharitableGift{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "missing gift_date is invalid" do
      attrs = Map.delete(@valid_attrs, :gift_date)
      changeset = CharitableGift.changeset(%CharitableGift{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).gift_date
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          recipient_type: "501c3",
          ein_number: "12-3456789",
          currency: "USD",
          gift_type: "securities",
          fair_market_value: Decimal.new("12000"),
          cost_basis: Decimal.new("5000"),
          tax_year: 2024,
          tax_deductible: true,
          deduction_limit_pct: Decimal.new("30"),
          acknowledgment_received: true,
          acknowledgment_date: ~D[2024-12-20],
          pledge_amount: Decimal.new("50000"),
          pledge_fulfilled: false,
          restricted_purpose: "Disaster relief",
          grant_agreement_id: "GA-2024-001",
          notes: "Year-end giving"
        })

      changeset = CharitableGift.changeset(%CharitableGift{}, attrs)
      assert changeset.valid?
    end

    test "recipient_types/0 returns expected list" do
      assert CharitableGift.recipient_types() == ~w(501c3 daf private_foundation public_charity religious educational other)
    end

    test "gift_types/0 returns expected list" do
      assert CharitableGift.gift_types() == ~w(cash securities property in_kind pledge)
    end
  end

  # ── 32. Finance.TrustTransaction (extended) ──────────────────────────

  describe "Finance.TrustTransaction edge cases" do
    alias Holdco.Finance.TrustTransaction

    @valid_attrs %{
      trust_account_id: 1,
      transaction_type: "contribution",
      amount: Decimal.new("50000"),
      transaction_date: ~D[2024-06-15]
    }

    test "accepts each valid transaction_type" do
      for tt <- ~w(contribution distribution income expense fee tax_payment) do
        changeset = TrustTransaction.changeset(%TrustTransaction{}, Map.put(@valid_attrs, :transaction_type, tt))
        assert changeset.valid?, "expected transaction_type #{tt} to be valid"
      end
    end

    test "accepts each valid category" do
      for cat <- ~w(principal income) do
        changeset = TrustTransaction.changeset(%TrustTransaction{}, Map.put(@valid_attrs, :category, cat))
        assert changeset.valid?, "expected category #{cat} to be valid"
      end
    end

    test "invalid category is rejected" do
      attrs = Map.put(@valid_attrs, :category, "gains")
      changeset = TrustTransaction.changeset(%TrustTransaction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).category
    end

    test "amount must be greater than 0" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("0"))
      changeset = TrustTransaction.changeset(%TrustTransaction{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "negative amount is invalid" do
      attrs = Map.put(@valid_attrs, :amount, Decimal.new("-100"))
      changeset = TrustTransaction.changeset(%TrustTransaction{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "missing transaction_date is invalid" do
      attrs = Map.delete(@valid_attrs, :transaction_date)
      changeset = TrustTransaction.changeset(%TrustTransaction{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).transaction_date
    end

    test "transaction_types/0 returns expected list" do
      assert TrustTransaction.transaction_types() == ~w(contribution distribution income expense fee tax_payment)
    end

    test "categories/0 returns expected list" do
      assert TrustTransaction.categories() == ~w(principal income)
    end
  end

  # ── 33. Governance.EstatePlan (extended) ─────────────────────────────

  describe "Governance.EstatePlan edge cases" do
    alias Holdco.Governance.EstatePlan

    @valid_attrs %{plan_name: "Smith Will", plan_type: "will", principal_name: "John Smith"}

    test "accepts each valid plan_type" do
      for pt <- ~w(will trust power_of_attorney healthcare_directive beneficiary_designation buy_sell_agreement) do
        changeset = EstatePlan.changeset(%EstatePlan{}, Map.put(@valid_attrs, :plan_type, pt))
        assert changeset.valid?, "expected plan_type #{pt} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(draft executed filed superseded revoked) do
        changeset = EstatePlan.changeset(%EstatePlan{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "estimated_estate_value must be >= 0" do
      attrs = Map.put(@valid_attrs, :estimated_estate_value, Decimal.new("-1"))
      changeset = EstatePlan.changeset(%EstatePlan{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).estimated_estate_value
    end

    test "estimated_estate_value zero is valid" do
      attrs = Map.put(@valid_attrs, :estimated_estate_value, Decimal.new("0"))
      changeset = EstatePlan.changeset(%EstatePlan{}, attrs)
      assert changeset.valid?
    end

    test "missing principal_name is invalid" do
      attrs = Map.delete(@valid_attrs, :principal_name)
      changeset = EstatePlan.changeset(%EstatePlan{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).principal_name
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          family_charter_id: 1,
          attorney_name: "Jane Lawyer",
          executor_name: "Bob Executor",
          status: "executed",
          effective_date: ~D[2024-01-01],
          last_reviewed_date: ~D[2024-06-01],
          next_review_date: ~D[2025-06-01],
          key_provisions: "Equal distribution among children",
          asset_summary: %{"real_estate" => "2M", "securities" => "5M"},
          estimated_estate_value: Decimal.new("7000000"),
          currency: "USD",
          tax_implications: "Estate tax exemption applies",
          notes: "Reviewed by attorney"
        })

      changeset = EstatePlan.changeset(%EstatePlan{}, attrs)
      assert changeset.valid?
    end

    test "plan_types/0 returns expected list" do
      assert EstatePlan.plan_types() == ~w(will trust power_of_attorney healthcare_directive beneficiary_designation buy_sell_agreement)
    end
  end

  # ── 34. Governance.FamilyMember (extended) ───────────────────────────

  describe "Governance.FamilyMember edge cases" do
    alias Holdco.Governance.FamilyMember

    @valid_attrs %{family_charter_id: 1, full_name: "Alice Smith", relationship: "daughter"}

    test "accepts each valid role_in_family_office" do
      for role <- ~w(member trustee advisor director officer beneficiary) do
        changeset = FamilyMember.changeset(%FamilyMember{}, Map.put(@valid_attrs, :role_in_family_office, role))
        assert changeset.valid?, "expected role #{role} to be valid"
      end
    end

    test "accepts each valid employment_status" do
      for es <- ~w(not_employed employed advisory) do
        changeset = FamilyMember.changeset(%FamilyMember{}, Map.put(@valid_attrs, :employment_status, es))
        assert changeset.valid?, "expected employment_status #{es} to be valid"
      end
    end

    test "generation must be greater than 0" do
      attrs = Map.put(@valid_attrs, :generation, 0)
      changeset = FamilyMember.changeset(%FamilyMember{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).generation
    end

    test "negative generation is invalid" do
      attrs = Map.put(@valid_attrs, :generation, -1)
      changeset = FamilyMember.changeset(%FamilyMember{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).generation
    end

    test "generation of 1 is valid" do
      attrs = Map.put(@valid_attrs, :generation, 1)
      changeset = FamilyMember.changeset(%FamilyMember{}, attrs)
      assert changeset.valid?
    end

    test "missing relationship is invalid" do
      attrs = Map.delete(@valid_attrs, :relationship)
      changeset = FamilyMember.changeset(%FamilyMember{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).relationship
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          generation: 2,
          date_of_birth: ~D[1990-05-15],
          role_in_family_office: "director",
          voting_rights: true,
          board_eligible: true,
          employment_status: "employed",
          branch: "Main branch",
          contact_email: "alice@smithfamily.com",
          notes: "Active board participant"
        })

      changeset = FamilyMember.changeset(%FamilyMember{}, attrs)
      assert changeset.valid?
    end

    test "roles/0 returns expected list" do
      assert FamilyMember.roles() == ~w(member trustee advisor director officer beneficiary)
    end

    test "employment_statuses/0 returns expected list" do
      assert FamilyMember.employment_statuses() == ~w(not_employed employed advisory)
    end
  end

  # ── 35. Governance.SuccessionPlan (extended) ─────────────────────────

  describe "Governance.SuccessionPlan edge cases" do
    alias Holdco.Governance.SuccessionPlan

    @valid_attrs %{company_id: 1, position_title: "CEO", current_holder: "John Smith"}

    test "accepts each valid timeline" do
      for tl <- ~w(immediate short_term long_term) do
        changeset = SuccessionPlan.changeset(%SuccessionPlan{}, Map.put(@valid_attrs, :timeline, tl))
        assert changeset.valid?, "expected timeline #{tl} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(active triggered completed archived) do
        changeset = SuccessionPlan.changeset(%SuccessionPlan{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid timeline is rejected" do
      attrs = Map.put(@valid_attrs, :timeline, "never")
      changeset = SuccessionPlan.changeset(%SuccessionPlan{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).timeline
    end

    test "missing current_holder is invalid" do
      attrs = Map.delete(@valid_attrs, :current_holder)
      changeset = SuccessionPlan.changeset(%SuccessionPlan{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).current_holder
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          successor_candidates: [%{"name" => "Jane Smith", "readiness" => "ready"}],
          timeline: "short_term",
          status: "active",
          trigger_events: ["retirement", "incapacitation"],
          last_reviewed_date: ~D[2024-06-01],
          next_review_date: ~D[2025-06-01],
          notes: "Reviewed by board"
        })

      changeset = SuccessionPlan.changeset(%SuccessionPlan{}, attrs)
      assert changeset.valid?
    end

    test "timelines/0 returns expected list" do
      assert SuccessionPlan.timelines() == ~w(immediate short_term long_term)
    end

    test "statuses/0 returns expected list" do
      assert SuccessionPlan.statuses() == ~w(active triggered completed archived)
    end
  end

  # ── 36. Platform.DataLineage (extended) ──────────────────────────────

  describe "Platform.DataLineage edge cases" do
    alias Holdco.Platform.DataLineage

    @valid_attrs %{source_type: "manual_entry", target_entity_type: "transaction", target_entity_id: 42}

    test "accepts each valid source_type" do
      for st <- ~w(manual_entry import bank_feed api_sync calculation migration) do
        changeset = DataLineage.changeset(%DataLineage{}, Map.put(@valid_attrs, :source_type, st))
        assert changeset.valid?, "expected source_type #{st} to be valid"
      end
    end

    test "accepts each valid confidence level" do
      for cl <- ~w(high medium low) do
        changeset = DataLineage.changeset(%DataLineage{}, Map.put(@valid_attrs, :confidence, cl))
        assert changeset.valid?, "expected confidence #{cl} to be valid"
      end
    end

    test "invalid source_type is rejected" do
      attrs = Map.put(@valid_attrs, :source_type, "unknown")
      changeset = DataLineage.changeset(%DataLineage{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).source_type
    end

    test "invalid confidence is rejected" do
      attrs = Map.put(@valid_attrs, :confidence, "uncertain")
      changeset = DataLineage.changeset(%DataLineage{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).confidence
    end

    test "missing target_entity_id is invalid" do
      attrs = Map.delete(@valid_attrs, :target_entity_id)
      changeset = DataLineage.changeset(%DataLineage{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).target_entity_id
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          source_identifier: "bank_feed_123",
          transformation: "auto_categorized",
          confidence: "medium",
          verified: true,
          verified_by_id: 1,
          verified_at: ~U[2024-06-15 10:00:00Z],
          notes: "Verified by admin"
        })

      changeset = DataLineage.changeset(%DataLineage{}, attrs)
      assert changeset.valid?
    end

    test "source_types/0 returns expected list" do
      assert DataLineage.source_types() == ~w(manual_entry import bank_feed api_sync calculation migration)
    end

    test "confidence_levels/0 returns expected list" do
      assert DataLineage.confidence_levels() == ~w(high medium low)
    end
  end

  # ── 37. Platform.Plugin (extended) ───────────────────────────────────

  describe "Platform.Plugin edge cases" do
    alias Holdco.Platform.Plugin

    @valid_attrs %{name: "Tax Calculator", slug: "tax-calculator", plugin_type: "automation"}

    test "accepts each valid plugin_type" do
      for pt <- ~w(integration report widget automation data_source) do
        changeset = Plugin.changeset(%Plugin{}, Map.put(@valid_attrs, :plugin_type, pt))
        assert changeset.valid?, "expected plugin_type #{pt} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(installed active disabled error) do
        changeset = Plugin.changeset(%Plugin{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid plugin_type is rejected" do
      attrs = Map.put(@valid_attrs, :plugin_type, "malware")
      changeset = Plugin.changeset(%Plugin{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).plugin_type
    end

    test "missing slug is invalid" do
      attrs = Map.delete(@valid_attrs, :slug)
      changeset = Plugin.changeset(%Plugin{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).slug
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          description: "Automated tax calculation plugin",
          version: "2.1.0",
          author: "Holdco Team",
          status: "active",
          config: %{"api_endpoint" => "https://api.tax.com"},
          permissions_required: ["read_transactions", "write_tax_records"],
          entry_module: "HoldcoPlugins.TaxCalculator",
          installed_at: ~U[2024-01-01 00:00:00Z],
          last_activated_at: ~U[2024-06-15 00:00:00Z],
          error_log: nil,
          notes: "Production ready"
        })

      changeset = Plugin.changeset(%Plugin{}, attrs)
      assert changeset.valid?
    end

    test "plugin_types/0 returns expected list" do
      assert Plugin.plugin_types() == ~w(integration report widget automation data_source)
    end

    test "statuses/0 returns expected list" do
      assert Plugin.statuses() == ~w(installed active disabled error)
    end
  end

  # ── 38. Platform.QuickAction (extended) ──────────────────────────────

  describe "Platform.QuickAction edge cases" do
    alias Holdco.Platform.QuickAction

    @valid_attrs %{name: "New Transaction", action_type: "create", target_path: "/transactions/new"}

    test "accepts each valid action_type" do
      for at <- ~w(navigate create search export) do
        changeset = QuickAction.changeset(%QuickAction{}, Map.put(@valid_attrs, :action_type, at))
        assert changeset.valid?, "expected action_type #{at} to be valid"
      end
    end

    test "accepts each valid category" do
      for cat <- ~w(portfolio fund corporate accounting tax risk reports settings) do
        changeset = QuickAction.changeset(%QuickAction{}, Map.put(@valid_attrs, :category, cat))
        assert changeset.valid?, "expected category #{cat} to be valid"
      end
    end

    test "invalid action_type is rejected" do
      attrs = Map.put(@valid_attrs, :action_type, "destroy")
      changeset = QuickAction.changeset(%QuickAction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).action_type
    end

    test "invalid category is rejected" do
      attrs = Map.put(@valid_attrs, :category, "unknown")
      changeset = QuickAction.changeset(%QuickAction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).category
    end

    test "missing target_path is invalid" do
      attrs = Map.delete(@valid_attrs, :target_path)
      changeset = QuickAction.changeset(%QuickAction{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).target_path
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          description: "Create a new transaction record",
          icon: "plus-circle",
          category: "accounting",
          search_keywords: ["transaction", "payment", "new"],
          sort_order: 10,
          is_enabled: true
        })

      changeset = QuickAction.changeset(%QuickAction{}, attrs)
      assert changeset.valid?
    end

    test "action_types/0 returns expected list" do
      assert QuickAction.action_types() == ~w(navigate create search export)
    end

    test "categories/0 returns expected list" do
      assert QuickAction.categories() == ~w(portfolio fund corporate accounting tax risk reports settings)
    end
  end

  # ── 39. Corporate.RegisterEntry (extended) ───────────────────────────

  describe "Corporate.RegisterEntry edge cases" do
    alias Holdco.Corporate.RegisterEntry

    @valid_attrs %{company_id: 1, register_type: "directors", entry_date: "2024-01-15"}

    test "accepts each valid register_type" do
      for rt <- ~w(directors shareholders charges mortgages debentures beneficial_owners secretary auditors registered_office) do
        changeset = RegisterEntry.changeset(%RegisterEntry{}, Map.put(@valid_attrs, :register_type, rt))
        assert changeset.valid?, "expected register_type #{rt} to be valid"
      end
    end

    test "accepts each valid status" do
      for st <- ~w(current historical) do
        changeset = RegisterEntry.changeset(%RegisterEntry{}, Map.put(@valid_attrs, :status, st))
        assert changeset.valid?, "expected status #{st} to be valid"
      end
    end

    test "invalid entry_date format is rejected" do
      attrs = Map.put(@valid_attrs, :entry_date, "15-01-2024")
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      refute changeset.valid?
      assert "must be a valid date (YYYY-MM-DD)" in errors_on(changeset).entry_date
    end

    test "invalid appointment_date format is rejected" do
      attrs = Map.put(@valid_attrs, :appointment_date, "not_a_date")
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      refute changeset.valid?
      assert "must be a valid date (YYYY-MM-DD)" in errors_on(changeset).appointment_date
    end

    test "invalid cessation_date format is rejected" do
      attrs = Map.put(@valid_attrs, :cessation_date, "12/31/2024")
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      refute changeset.valid?
      assert "must be a valid date (YYYY-MM-DD)" in errors_on(changeset).cessation_date
    end

    test "valid ISO date in appointment_date is accepted" do
      attrs = Map.put(@valid_attrs, :appointment_date, "2024-03-01")
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      assert changeset.valid?
    end

    test "shares_held must be >= 0" do
      attrs = Map.put(@valid_attrs, :shares_held, Decimal.new("-1"))
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).shares_held
    end

    test "shares_held zero is valid" do
      attrs = Map.put(@valid_attrs, :shares_held, Decimal.new("0"))
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          person_name: "Jane Director",
          role_or_description: "Independent Director",
          shares_held: Decimal.new("10000"),
          share_class: "Ordinary",
          appointment_date: "2024-01-15",
          cessation_date: nil,
          status: "current",
          notes: "Appointed at AGM"
        })

      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      assert changeset.valid?
    end

    test "register_types/0 returns expected list" do
      assert RegisterEntry.register_types() == ~w(directors shareholders charges mortgages debentures beneficial_owners secretary auditors registered_office)
    end

    test "statuses/0 returns expected list" do
      assert RegisterEntry.statuses() == ~w(current historical)
    end
  end
end
