defmodule Holdco.Workers.S3UploadTest do
  use ExUnit.Case, async: true

  alias Holdco.Workers.S3Upload

  describe "configured?/0" do
    test "returns false when no configuration is set" do
      # Default test config has no S3 settings
      refute S3Upload.configured?()
    end

    test "returns false when only partial configuration exists" do
      original = Application.get_env(:holdco, Holdco.Workers.S3Upload)

      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        access_key_id: nil,
        secret_access_key: nil
      )

      refute S3Upload.configured?()

      if original do
        Application.put_env(:holdco, Holdco.Workers.S3Upload, original)
      else
        Application.delete_env(:holdco, Holdco.Workers.S3Upload)
      end
    end

    test "returns true when all required fields are present" do
      original = Application.get_env(:holdco, Holdco.Workers.S3Upload)

      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        endpoint: "s3.amazonaws.com",
        region: "us-east-1",
        access_key_id: "AKIAIOSFODNN7EXAMPLE",
        secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      )

      assert S3Upload.configured?()

      if original do
        Application.put_env(:holdco, Holdco.Workers.S3Upload, original)
      else
        Application.delete_env(:holdco, Holdco.Workers.S3Upload)
      end
    end
  end

  describe "config/0" do
    test "returns keyword list from application config" do
      cfg = S3Upload.config()
      assert is_list(cfg)
    end
  end

  describe "upload/2" do
    test "returns error when not configured" do
      assert {:error, "S3 not configured"} = S3Upload.upload("/tmp/test.dump", "backups/test.dump")
    end
  end

  describe "sign_v4/9" do
    test "generates a valid AWS Signature V4 authorization header" do
      headers = %{
        "host" => "test-bucket.s3.amazonaws.com",
        "x-amz-content-sha256" => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "x-amz-date" => "20260228T120000Z"
      }

      auth =
        S3Upload.sign_v4(
          "PUT",
          "/backups/test.dump",
          headers,
          "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKIAIOSFODNN7EXAMPLE",
          "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

      assert auth =~ "AWS4-HMAC-SHA256"
      assert auth =~ "Credential=AKIAIOSFODNN7EXAMPLE/20260228/us-east-1/s3/aws4_request"
      assert auth =~ "SignedHeaders=host;x-amz-content-sha256;x-amz-date"
      assert auth =~ "Signature="
    end

    test "produces deterministic signatures for same inputs" do
      headers = %{
        "host" => "bucket.s3.amazonaws.com",
        "x-amz-content-sha256" => "abc123",
        "x-amz-date" => "20260228T000000Z"
      }

      args = [
        "PUT",
        "/key",
        headers,
        "abc123",
        "us-east-1",
        "20260228",
        "20260228T000000Z",
        "AKID",
        "SECRET"
      ]

      sig1 = apply(S3Upload, :sign_v4, args)
      sig2 = apply(S3Upload, :sign_v4, args)

      assert sig1 == sig2
    end

    test "different keys produce different signatures" do
      headers = %{
        "host" => "bucket.s3.amazonaws.com",
        "x-amz-content-sha256" => "abc123",
        "x-amz-date" => "20260228T000000Z"
      }

      base_args = [
        "PUT",
        "/key",
        headers,
        "abc123",
        "us-east-1",
        "20260228",
        "20260228T000000Z"
      ]

      sig1 = apply(S3Upload, :sign_v4, base_args ++ ["KEY1", "SECRET1"])
      sig2 = apply(S3Upload, :sign_v4, base_args ++ ["KEY2", "SECRET2"])

      refute sig1 == sig2
    end

    test "different regions produce different signatures" do
      headers = %{
        "host" => "bucket.s3.amazonaws.com",
        "x-amz-content-sha256" => "abc123",
        "x-amz-date" => "20260228T000000Z"
      }

      sig1 =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          headers,
          "abc123",
          "us-east-1",
          "20260228",
          "20260228T000000Z",
          "AKID",
          "SECRET"
        )

      sig2 =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          headers,
          "abc123",
          "eu-west-1",
          "20260228",
          "20260228T000000Z",
          "AKID",
          "SECRET"
        )

      refute sig1 == sig2
    end
  end
end
