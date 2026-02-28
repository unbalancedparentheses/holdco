defmodule Holdco.Workers.S3UploadTest do
  use ExUnit.Case, async: true

  alias Holdco.Workers.S3Upload

  setup do
    original = Application.get_env(:holdco, Holdco.Workers.S3Upload)
    on_exit(fn -> Application.put_env(:holdco, Holdco.Workers.S3Upload, original || []) end)
  end

  describe "config/0" do
    test "returns a list from application config" do
      cfg = S3Upload.config()
      assert is_list(cfg)
    end

    test "returns empty list by default when no S3 config is set in test env" do
      assert S3Upload.config() == []
    end

    test "returns the configured values after Application.put_env" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "my-bucket",
        access_key_id: "AKID",
        secret_access_key: "SECRET"
      )

      cfg = S3Upload.config()
      assert cfg[:bucket] == "my-bucket"
      assert cfg[:access_key_id] == "AKID"
      assert cfg[:secret_access_key] == "SECRET"
    end
  end

  describe "configured?/0" do
    test "returns false when no configuration is set" do
      refute S3Upload.configured?()
    end

    test "returns false when only bucket is set" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        access_key_id: nil,
        secret_access_key: nil
      )

      refute S3Upload.configured?()
    end

    test "returns false when access_key_id is empty string" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        access_key_id: "",
        secret_access_key: "secret"
      )

      refute S3Upload.configured?()
    end

    test "returns false when secret_access_key is empty string" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        access_key_id: "AKID",
        secret_access_key: ""
      )

      refute S3Upload.configured?()
    end

    test "returns false when bucket is nil" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: nil,
        access_key_id: "AKID",
        secret_access_key: "SECRET"
      )

      refute S3Upload.configured?()
    end

    test "returns true when bucket, access_key_id, and secret_access_key are all set" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        endpoint: "s3.amazonaws.com",
        region: "us-east-1",
        access_key_id: "AKIAIOSFODNN7EXAMPLE",
        secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      )

      assert S3Upload.configured?()
    end
  end

  describe "upload/2" do
    test "returns {:error, \"S3 not configured\"} when not configured" do
      assert {:error, "S3 not configured"} = S3Upload.upload("/tmp/test.dump", "backups/test.dump")
    end

    test "returns error tuple with exact message string" do
      {:error, message} = S3Upload.upload("/any/path", "any/key")
      assert message == "S3 not configured"
    end
  end

  describe "sign_v4/9" do
    @test_headers %{
      "host" => "test-bucket.s3.amazonaws.com",
      "x-amz-content-sha256" => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "x-amz-date" => "20260228T120000Z"
    }

    test "returns a string starting with \"AWS4-HMAC-SHA256 Credential=\"" do
      auth =
        S3Upload.sign_v4(
          "PUT",
          "/backups/test.dump",
          @test_headers,
          "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKIAIOSFODNN7EXAMPLE",
          "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

      assert String.starts_with?(auth, "AWS4-HMAC-SHA256 Credential=")
    end

    test "credential includes the access key ID" do
      access_key = "AKIAIOSFODNN7EXAMPLE"

      auth =
        S3Upload.sign_v4(
          "PUT",
          "/backups/test.dump",
          @test_headers,
          "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          access_key,
          "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

      assert auth =~ "Credential=#{access_key}/"
    end

    test "includes SignedHeaders and Signature in the output" do
      auth =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          @test_headers,
          "abc123",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKID",
          "SECRET"
        )

      assert auth =~ "SignedHeaders="
      assert auth =~ "Signature="
    end

    test "signed headers are alphabetically sorted" do
      headers = %{
        "x-amz-date" => "20260228T120000Z",
        "host" => "bucket.s3.amazonaws.com",
        "content-type" => "application/octet-stream",
        "x-amz-content-sha256" => "abc123"
      }

      auth =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          headers,
          "abc123",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKID",
          "SECRET"
        )

      # Extract the SignedHeaders value from the authorization string
      [_, signed_headers_part] = String.split(auth, "SignedHeaders=")
      [signed_headers_str | _] = String.split(signed_headers_part, ",")
      signed_headers = String.split(String.trim(signed_headers_str), ";")

      assert signed_headers == Enum.sort(signed_headers)
      assert signed_headers == ["content-type", "host", "x-amz-content-sha256", "x-amz-date"]
    end

    test "credential includes date_stamp/region/s3/aws4_request scope" do
      auth =
        S3Upload.sign_v4(
          "PUT",
          "/backups/test.dump",
          @test_headers,
          "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKIAIOSFODNN7EXAMPLE",
          "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

      assert auth =~ "Credential=AKIAIOSFODNN7EXAMPLE/20260228/us-east-1/s3/aws4_request"
    end

    test "produces deterministic signatures for same inputs" do
      args = [
        "PUT",
        "/key",
        @test_headers,
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

    test "different secret keys produce different signatures" do
      base_args = [
        "PUT",
        "/key",
        @test_headers,
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
      sig1 =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          @test_headers,
          "abc123",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKID",
          "SECRET"
        )

      sig2 =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          @test_headers,
          "abc123",
          "eu-west-1",
          "20260228",
          "20260228T120000Z",
          "AKID",
          "SECRET"
        )

      refute sig1 == sig2
    end

    test "signature is a lowercase hex string" do
      auth =
        S3Upload.sign_v4(
          "PUT",
          "/key",
          @test_headers,
          "abc123",
          "us-east-1",
          "20260228",
          "20260228T120000Z",
          "AKID",
          "SECRET"
        )

      # Extract the Signature= value at the end
      [_, signature] = String.split(auth, "Signature=")
      assert Regex.match?(~r/^[a-f0-9]{64}$/, signature)
    end
  end

  describe "upload/2 when configured" do
    setup do
      # Configure S3 with a fake endpoint that will fail on HTTP call
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "test-bucket",
        endpoint: "https://localhost:19999",
        region: "us-east-1",
        access_key_id: "AKIAIOSFODNN7EXAMPLE",
        secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      )

      # Create a temp file
      tmp = Path.join(System.tmp_dir!(), "s3_upload_test_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp, "test data for s3 upload")
      on_exit(fn -> File.rm(tmp) end)

      %{tmp_file: tmp}
    end

    test "attempts upload and returns error when endpoint is unreachable", %{tmp_file: tmp} do
      result = S3Upload.upload(tmp, "backups/test.dump")
      assert {:error, message} = result
      assert is_binary(message)
    end

    test "exercises the full do_upload code path with valid file", %{tmp_file: tmp} do
      # This will fail at the HTTP request level but exercises signing, hashing, etc.
      {:error, _reason} = S3Upload.upload(tmp, "test/key.txt")
    end

    test "returns error when file does not exist" do
      result = S3Upload.upload("/nonexistent/file.txt", "test/key.txt")
      assert {:error, _message} = result
    end
  end

  describe "upload/2 with endpoint variations" do
    setup do
      on_exit(fn -> Application.put_env(:holdco, Holdco.Workers.S3Upload, []) end)
    end

    test "handles endpoint without protocol prefix" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "my-bucket",
        endpoint: "s3.amazonaws.com",
        region: "us-east-1",
        access_key_id: "AKID",
        secret_access_key: "SECRET"
      )

      tmp = Path.join(System.tmp_dir!(), "s3_test_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp, "data")
      on_exit(fn -> File.rm(tmp) end)

      {:error, _} = S3Upload.upload(tmp, "test/key.txt")
    end

    test "handles endpoint with https:// prefix" do
      Application.put_env(:holdco, Holdco.Workers.S3Upload,
        bucket: "my-bucket",
        endpoint: "https://r2.cloudflarestorage.com",
        region: "auto",
        access_key_id: "AKID",
        secret_access_key: "SECRET"
      )

      tmp = Path.join(System.tmp_dir!(), "s3_test_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp, "data")
      on_exit(fn -> File.rm(tmp) end)

      {:error, _} = S3Upload.upload(tmp, "test/key.txt")
    end
  end
end
