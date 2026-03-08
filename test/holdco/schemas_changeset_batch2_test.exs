defmodule Holdco.SchemasChangesetBatch2Test do
  use Holdco.DataCase, async: true

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
