defmodule KlassHero.Enrollment.Domain.Models.BulkEnrollmentInviteTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Models.BulkEnrollmentInvite

  @valid_attrs %{
    id: "inv-1",
    program_id: "prog-1",
    provider_id: "prov-1",
    status: :pending,
    guardian_email: "parent@example.com",
    child_first_name: "Emma",
    child_last_name: "Schmidt"
  }

  describe "generate_token/0" do
    test "returns a URL-safe base64 string" do
      token = BulkEnrollmentInvite.generate_token()

      assert is_binary(token)
      assert {:ok, _decoded} = Base.url_decode64(token, padding: false)
    end

    test "generates unique tokens" do
      tokens = for _ <- 1..10, do: BulkEnrollmentInvite.generate_token()

      assert length(Enum.uniq(tokens)) == 10
    end
  end

  describe "from_persistence/1" do
    test "returns {:ok, invite} with valid attrs" do
      assert {:ok, %BulkEnrollmentInvite{id: "inv-1"}} =
               BulkEnrollmentInvite.from_persistence(@valid_attrs)
    end

    test "returns {:error, :invalid_persistence_data} when required keys missing" do
      assert {:error, :invalid_persistence_data} =
               BulkEnrollmentInvite.from_persistence(%{id: "inv-1"})
    end
  end

  describe "pending?/1" do
    test "returns true for pending status" do
      {:ok, invite} = BulkEnrollmentInvite.from_persistence(@valid_attrs)
      assert BulkEnrollmentInvite.pending?(invite)
    end

    test "returns false for other statuses" do
      {:ok, invite} =
        BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: :invite_sent})

      refute BulkEnrollmentInvite.pending?(invite)
    end
  end

  describe "invite_sent?/1" do
    test "returns true for invite_sent status" do
      {:ok, invite} =
        BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: :invite_sent})

      assert BulkEnrollmentInvite.invite_sent?(invite)
    end

    test "returns false for other statuses" do
      {:ok, invite} = BulkEnrollmentInvite.from_persistence(@valid_attrs)
      refute BulkEnrollmentInvite.invite_sent?(invite)
    end
  end

  describe "resendable?/1" do
    for status <- [:pending, :invite_sent, :failed] do
      test "returns true for #{status} status" do
        {:ok, invite} =
          BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: unquote(status)})

        assert BulkEnrollmentInvite.resendable?(invite)
      end
    end

    for status <- [:registered, :enrolled] do
      test "returns false for #{status} status" do
        {:ok, invite} =
          BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: unquote(status)})

        refute BulkEnrollmentInvite.resendable?(invite)
      end
    end
  end

  describe "ensure_resendable/1" do
    for status <- [:pending, :invite_sent, :failed] do
      test "returns {:ok, invite} for #{status} status" do
        {:ok, invite} =
          BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: unquote(status)})

        assert {:ok, ^invite} = BulkEnrollmentInvite.ensure_resendable(invite)
      end
    end

    for status <- [:registered, :enrolled] do
      test "returns {:error, :not_resendable} for #{status} status" do
        {:ok, invite} =
          BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: unquote(status)})

        assert {:error, :not_resendable} = BulkEnrollmentInvite.ensure_resendable(invite)
      end
    end
  end

  describe "ensure_claimable/1" do
    test "returns {:ok, invite} for :invite_sent status" do
      {:ok, invite} =
        BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: :invite_sent})

      assert {:ok, ^invite} = BulkEnrollmentInvite.ensure_claimable(invite)
    end

    for status <- [:pending, :registered, :enrolled, :failed] do
      test "returns {:error, :already_claimed} for #{status} status" do
        {:ok, invite} =
          BulkEnrollmentInvite.from_persistence(%{@valid_attrs | status: unquote(status)})

        assert {:error, :already_claimed} = BulkEnrollmentInvite.ensure_claimable(invite)
      end
    end
  end
end
