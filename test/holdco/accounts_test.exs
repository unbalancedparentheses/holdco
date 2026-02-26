defmodule Holdco.AccountsTest do
  use Holdco.DataCase

  alias Holdco.Accounts

  import Holdco.AccountsFixtures
  alias Holdco.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end

    test "returns false when authenticated_at is nil" do
      refute Accounts.sudo_mode?(%User{authenticated_at: nil})
    end

    test "custom minute override" do
      now = DateTime.utc_now()
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -5, :minute)}, -10)
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -15, :minute)}, -10)
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end

    test "accepts valid email" do
      changeset = Accounts.change_user_email(%User{}, %{email: "new@example.com"})
      assert changeset.valid?
    end

    test "rejects invalid email" do
      changeset = Accounts.change_user_email(%User{}, %{email: "not-valid"})
      refute changeset.valid?
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    setup do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      %{user: user, token: encoded_token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_magic_link_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "login_user_by_magic_link/1" do
    test "confirms user and expires tokens" do
      user = unconfirmed_user_fixture()
      refute user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user" do
      user = user_fixture()
      assert user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      assert {:ok, {^user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set" do
      user = unconfirmed_user_fixture()
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end

    test "raises or errors for invalid token" do
      # An invalid token that can't be decoded causes a MatchError in verify_magic_link_token_query
      assert_raise MatchError, fn ->
        Accounts.login_user_by_magic_link("invalid_token")
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{user: unconfirmed_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "login"
    end
  end

  # ── TOTP ──────────────────────────────────────────────

  describe "TOTP functions" do
    test "generate_totp_secret returns a binary secret" do
      secret = Accounts.generate_totp_secret()
      assert is_binary(secret)
      assert byte_size(secret) > 0
    end

    test "generate_totp_secret generates unique secrets" do
      s1 = Accounts.generate_totp_secret()
      s2 = Accounts.generate_totp_secret()
      assert s1 != s2
    end

    test "enable and disable TOTP for user" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()

      {:ok, enabled_user} = Accounts.enable_totp(user, secret)
      assert enabled_user.totp_enabled == true
      assert enabled_user.totp_secret == secret

      {:ok, disabled_user} = Accounts.disable_totp(enabled_user)
      assert disabled_user.totp_enabled == false
      assert disabled_user.totp_secret == nil
    end

    test "valid_totp? returns false when user has no secret" do
      refute Accounts.valid_totp?(%User{totp_secret: nil}, "123456")
    end

    test "valid_totp? returns false when code is not binary" do
      refute Accounts.valid_totp?(%User{totp_secret: "secret"}, nil)
    end

    test "valid_totp? returns true for valid code" do
      secret = Accounts.generate_totp_secret()
      code = NimbleTOTP.verification_code(secret)
      assert Accounts.valid_totp?(%User{totp_secret: secret}, code)
    end

    test "totp_uri generates otpauth URI" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      uri = Accounts.totp_uri(user, secret)
      assert String.starts_with?(uri, "otpauth://totp/")
      assert String.contains?(uri, "Holdco")
    end

    test "totp_qr_svg generates SVG QR code" do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      svg = Accounts.totp_qr_svg(user, secret)
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end
  end

  # ── User Roles ────────────────────────────────────────

  describe "user roles" do
    test "get_user_role returns viewer for user with no role set" do
      user = user_fixture()
      assert Accounts.get_user_role(user) == "viewer"
    end

    test "set_user_role and get_user_role" do
      user = user_fixture()
      {:ok, _} = Accounts.set_user_role(user, "admin")
      assert Accounts.get_user_role(user) == "admin"

      {:ok, _} = Accounts.set_user_role(user, "editor")
      assert Accounts.get_user_role(user) == "editor"

      {:ok, _} = Accounts.set_user_role(user, "viewer")
      assert Accounts.get_user_role(user) == "viewer"
    end

    test "admin? and editor? predicates" do
      user = user_fixture()

      # Default (no role) -> viewer
      refute Accounts.admin?(user)
      refute Accounts.editor?(user)

      {:ok, _} = Accounts.set_user_role(user, "admin")
      assert Accounts.admin?(user)
      assert Accounts.editor?(user)

      {:ok, _} = Accounts.set_user_role(user, "editor")
      refute Accounts.admin?(user)
      assert Accounts.editor?(user)

      {:ok, _} = Accounts.set_user_role(user, "viewer")
      refute Accounts.admin?(user)
      refute Accounts.editor?(user)
    end
  end

  # ── API Keys ──────────────────────────────────────────

  describe "api_keys" do
    test "list_api_keys returns empty list when no keys exist" do
      user = user_fixture()
      assert Accounts.list_api_keys(user.id) == []
    end

    test "create_api_key creates and list_api_keys returns keys" do
      user = user_fixture()
      {:ok, key} = Accounts.create_api_key(user, "Test Key")

      assert key.name == "Test Key"
      assert key.user_id == user.id
      assert is_binary(key.key)

      keys = Accounts.list_api_keys(user.id)
      assert length(keys) == 1
      assert hd(keys).id == key.id
    end

    test "create_api_key generates unique keys" do
      user = user_fixture()
      {:ok, k1} = Accounts.create_api_key(user, "Key 1")
      {:ok, k2} = Accounts.create_api_key(user, "Key 2")
      assert k1.key != k2.key
    end

    test "delete_api_key deletes the key" do
      user = user_fixture()
      {:ok, key} = Accounts.create_api_key(user, "To Delete")
      {:ok, _} = Accounts.delete_api_key(key)
      assert Accounts.list_api_keys(user.id) == []
    end

    test "get_api_key! returns and raises appropriately" do
      user = user_fixture()
      {:ok, key} = Accounts.create_api_key(user, "Get Key")
      assert Accounts.get_api_key!(key.id).id == key.id

      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_api_key!(-1)
      end
    end

    test "list_api_keys does not return keys for other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      {:ok, _} = Accounts.create_api_key(user1, "Key 1")

      assert Accounts.list_api_keys(user2.id) == []
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
