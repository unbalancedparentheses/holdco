defmodule Holdco.Workers.S3Upload do
  @moduledoc """
  Helper module for uploading files to S3-compatible storage (AWS S3, Cloudflare R2, MinIO).
  Uses Req for HTTP requests and implements AWS Signature V4 for authentication.
  """

  require Logger

  @doc """
  Returns the S3 configuration from application config.
  """
  def config do
    Application.get_env(:holdco, __MODULE__, [])
  end

  @doc """
  Returns true if S3 upload is configured with required credentials.
  """
  def configured? do
    cfg = config()
    cfg[:bucket] not in [nil, ""] and
      cfg[:access_key_id] not in [nil, ""] and
      cfg[:secret_access_key] not in [nil, ""]
  end

  @doc """
  Upload a file to S3-compatible storage.

  ## Parameters
    - file_path: Local path to the file to upload
    - key: The S3 object key (path within the bucket)

  ## Returns
    - {:ok, %{status: status, url: url}} on success
    - {:error, reason} on failure
  """
  def upload(file_path, key) do
    if not configured?() do
      {:error, "S3 not configured"}
    else
      do_upload(file_path, key)
    end
  end

  defp do_upload(file_path, key) do
    cfg = config()
    bucket = cfg[:bucket]
    endpoint = cfg[:endpoint] || "s3.amazonaws.com"
    region = cfg[:region] || "us-east-1"
    access_key_id = cfg[:access_key_id]
    secret_access_key = cfg[:secret_access_key]

    body = File.read!(file_path)
    content_hash = sha256_hex(body)
    now = DateTime.utc_now()
    date_stamp = Calendar.strftime(now, "%Y%m%d")
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")

    host = build_host(bucket, endpoint)
    url = build_url(host, key)

    headers = %{
      "host" => host,
      "x-amz-date" => amz_date,
      "x-amz-content-sha256" => content_hash,
      "content-type" => "application/octet-stream"
    }

    authorization =
      sign_v4(
        "PUT",
        "/#{key}",
        headers,
        content_hash,
        region,
        date_stamp,
        amz_date,
        access_key_id,
        secret_access_key
      )

    req_headers =
      headers
      |> Map.put("authorization", authorization)
      |> Map.to_list()

    case Req.put(url, body: body, headers: req_headers, receive_timeout: 120_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, %{status: status, url: url}}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.error("S3 upload failed: status=#{status} body=#{inspect(resp_body)}")
        {:error, "S3 upload failed with status #{status}"}

      {:error, reason} ->
        Logger.error("S3 upload error: #{inspect(reason)}")
        {:error, "S3 upload error: #{inspect(reason)}"}
    end
  rescue
    e ->
      Logger.error("S3 upload exception: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  @doc """
  Build the AWS Signature V4 authorization header value.
  """
  def sign_v4(method, path, headers, payload_hash, region, date_stamp, amz_date, access_key_id, secret_access_key) do
    service = "s3"
    scope = "#{date_stamp}/#{region}/#{service}/aws4_request"

    signed_headers =
      headers
      |> Map.keys()
      |> Enum.sort()
      |> Enum.join(";")

    canonical_headers =
      headers
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> "#{k}:#{String.trim(v)}\n" end)
      |> Enum.join("")

    canonical_request =
      [method, path, "", canonical_headers, signed_headers, payload_hash]
      |> Enum.join("\n")

    string_to_sign =
      ["AWS4-HMAC-SHA256", amz_date, scope, sha256_hex(canonical_request)]
      |> Enum.join("\n")

    signing_key = derive_signing_key(secret_access_key, date_stamp, region, service)
    signature = hmac_sha256_hex(signing_key, string_to_sign)

    "AWS4-HMAC-SHA256 Credential=#{access_key_id}/#{scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"
  end

  defp derive_signing_key(secret_key, date_stamp, region, service) do
    ("AWS4" <> secret_key)
    |> hmac_sha256(date_stamp)
    |> hmac_sha256(region)
    |> hmac_sha256(service)
    |> hmac_sha256("aws4_request")
  end

  defp hmac_sha256(key, data) do
    :crypto.mac(:hmac, :sha256, key, data)
  end

  defp hmac_sha256_hex(key, data) do
    hmac_sha256(key, data) |> Base.encode16(case: :lower)
  end

  defp sha256_hex(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp build_host(bucket, endpoint) do
    if String.contains?(endpoint, "://") do
      uri = URI.parse(endpoint)
      "#{bucket}.#{uri.host}"
    else
      "#{bucket}.#{endpoint}"
    end
  end

  defp build_url(host, key) do
    "https://#{host}/#{key}"
  end
end
