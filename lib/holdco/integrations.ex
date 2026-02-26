defmodule Holdco.Integrations do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Integrations.{
    AccountingSyncConfig,
    AccountingSyncLog,
    BankFeedConfig,
    BankFeedTransaction,
    SignatureRequest,
    EmailDigestConfig
  }

  # Accounting Sync Configs
  def list_accounting_sync_configs do
    from(asc in AccountingSyncConfig, order_by: asc.provider, preload: [:company, :sync_logs])
    |> Repo.all()
  end

  def get_accounting_sync_config!(id) do
    Repo.get!(AccountingSyncConfig, id) |> Repo.preload([:company, :sync_logs])
  end

  def create_accounting_sync_config(attrs) do
    %AccountingSyncConfig{}
    |> AccountingSyncConfig.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("accounting_sync_configs", "create")
  end

  def update_accounting_sync_config(%AccountingSyncConfig{} = asc, attrs) do
    asc
    |> AccountingSyncConfig.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("accounting_sync_configs", "update")
  end

  def delete_accounting_sync_config(%AccountingSyncConfig{} = asc) do
    Repo.delete(asc)
    |> audit_and_broadcast("accounting_sync_configs", "delete")
  end

  # Accounting Sync Logs
  def list_accounting_sync_logs(config_id) do
    from(asl in AccountingSyncLog,
      where: asl.config_id == ^config_id,
      order_by: [desc: asl.inserted_at]
    )
    |> Repo.all()
  end

  def get_accounting_sync_log!(id), do: Repo.get!(AccountingSyncLog, id)

  def create_accounting_sync_log(attrs) do
    %AccountingSyncLog{}
    |> AccountingSyncLog.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("accounting_sync_logs", "create")
  end

  def update_accounting_sync_log(%AccountingSyncLog{} = asl, attrs) do
    asl
    |> AccountingSyncLog.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("accounting_sync_logs", "update")
  end

  def delete_accounting_sync_log(%AccountingSyncLog{} = asl) do
    Repo.delete(asl)
    |> audit_and_broadcast("accounting_sync_logs", "delete")
  end

  # Bank Feed Configs
  def list_bank_feed_configs do
    from(bfc in BankFeedConfig,
      order_by: bfc.provider,
      preload: [:company, :bank_account, :feed_transactions]
    )
    |> Repo.all()
  end

  def get_bank_feed_config!(id) do
    Repo.get!(BankFeedConfig, id) |> Repo.preload([:company, :bank_account, :feed_transactions])
  end

  def create_bank_feed_config(attrs) do
    %BankFeedConfig{}
    |> BankFeedConfig.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("bank_feed_configs", "create")
  end

  def update_bank_feed_config(%BankFeedConfig{} = bfc, attrs) do
    bfc
    |> BankFeedConfig.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("bank_feed_configs", "update")
  end

  def delete_bank_feed_config(%BankFeedConfig{} = bfc) do
    Repo.delete(bfc)
    |> audit_and_broadcast("bank_feed_configs", "delete")
  end

  # Bank Feed Transactions
  def list_bank_feed_transactions(feed_config_id) do
    from(bft in BankFeedTransaction,
      where: bft.feed_config_id == ^feed_config_id,
      order_by: [desc: bft.date]
    )
    |> Repo.all()
  end

  def get_bank_feed_transaction!(id), do: Repo.get!(BankFeedTransaction, id)

  def create_bank_feed_transaction(attrs) do
    %BankFeedTransaction{}
    |> BankFeedTransaction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("bank_feed_transactions", "create")
  end

  def update_bank_feed_transaction(%BankFeedTransaction{} = bft, attrs) do
    bft
    |> BankFeedTransaction.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("bank_feed_transactions", "update")
  end

  def delete_bank_feed_transaction(%BankFeedTransaction{} = bft) do
    Repo.delete(bft)
    |> audit_and_broadcast("bank_feed_transactions", "delete")
  end

  # Signature Requests
  def list_signature_requests(company_id \\ nil) do
    query =
      from(sr in SignatureRequest,
        order_by: [desc: sr.inserted_at],
        preload: [:company, :document]
      )

    query = if company_id, do: where(query, [sr], sr.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_signature_request!(id) do
    Repo.get!(SignatureRequest, id) |> Repo.preload([:company, :document])
  end

  def create_signature_request(attrs) do
    %SignatureRequest{}
    |> SignatureRequest.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("signature_requests", "create")
  end

  def update_signature_request(%SignatureRequest{} = sr, attrs) do
    sr
    |> SignatureRequest.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("signature_requests", "update")
  end

  def delete_signature_request(%SignatureRequest{} = sr) do
    Repo.delete(sr)
    |> audit_and_broadcast("signature_requests", "delete")
  end

  # Email Digest Configs
  def list_email_digest_configs do
    from(edc in EmailDigestConfig, order_by: [desc: edc.inserted_at], preload: [:user])
    |> Repo.all()
  end

  def get_email_digest_config!(id), do: Repo.get!(EmailDigestConfig, id) |> Repo.preload(:user)

  def get_email_digest_config_for_user(user_id) do
    Repo.get_by(EmailDigestConfig, user_id: user_id)
  end

  def create_email_digest_config(attrs) do
    %EmailDigestConfig{}
    |> EmailDigestConfig.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("email_digest_configs", "create")
  end

  def update_email_digest_config(%EmailDigestConfig{} = edc, attrs) do
    edc
    |> EmailDigestConfig.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("email_digest_configs", "update")
  end

  def delete_email_digest_config(%EmailDigestConfig{} = edc) do
    Repo.delete(edc)
    |> audit_and_broadcast("email_digest_configs", "delete")
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "integrations")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "integrations", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}

      error ->
        error
    end
  end
end
