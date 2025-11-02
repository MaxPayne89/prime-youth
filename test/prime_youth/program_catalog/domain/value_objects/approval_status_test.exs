defmodule PrimeYouth.ProgramCatalog.Domain.ValueObjects.ApprovalStatusTest do
  @moduledoc """
  Tests for ApprovalStatus value object.

  Tests cover:
  - Valid status creation
  - Invalid status rejection
  - Status transitions and validation
  - Display formatting
  - Status checks (draft?, approved?, etc.)
  """

  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.ApprovalStatus

  describe "new/1" do
    test "creates status with valid value" do
      assert {:ok, status} = ApprovalStatus.new("draft")
      assert status.value == "draft"
    end

    test "creates status with all valid statuses" do
      valid_statuses = [
        "draft",
        "pending_approval",
        "approved",
        "rejected",
        "archived"
      ]

      for status_name <- valid_statuses do
        assert {:ok, _status} = ApprovalStatus.new(status_name)
      end
    end

    test "rejects invalid status" do
      assert {:error, "Invalid status: invalid"} = ApprovalStatus.new("invalid")
    end

    test "rejects nil status" do
      assert {:error, "Status cannot be nil"} = ApprovalStatus.new(nil)
    end

    test "rejects empty string status" do
      assert {:error, "Status cannot be empty"} = ApprovalStatus.new("")
    end

    test "normalizes case to lowercase" do
      assert {:ok, status} = ApprovalStatus.new("DRAFT")
      assert status.value == "draft"
    end

    test "trims whitespace" do
      assert {:ok, status} = ApprovalStatus.new("  draft  ")
      assert status.value == "draft"
    end
  end

  describe "display_name/1" do
    test "returns formatted display name for draft" do
      {:ok, status} = ApprovalStatus.new("draft")
      assert ApprovalStatus.display_name(status) == "Draft"
    end

    test "returns formatted display name for pending_approval" do
      {:ok, status} = ApprovalStatus.new("pending_approval")
      assert ApprovalStatus.display_name(status) == "Pending Approval"
    end

    test "returns formatted display name for approved" do
      {:ok, status} = ApprovalStatus.new("approved")
      assert ApprovalStatus.display_name(status) == "Approved"
    end

    test "returns formatted display name for rejected" do
      {:ok, status} = ApprovalStatus.new("rejected")
      assert ApprovalStatus.display_name(status) == "Rejected"
    end

    test "returns formatted display name for archived" do
      {:ok, status} = ApprovalStatus.new("archived")
      assert ApprovalStatus.display_name(status) == "Archived"
    end
  end

  describe "all/0" do
    test "returns list of all valid statuses" do
      statuses = ApprovalStatus.all()

      expected = [
        "draft",
        "pending_approval",
        "approved",
        "rejected",
        "archived"
      ]

      assert Enum.sort(statuses) == Enum.sort(expected)
    end

    test "returns non-empty list" do
      statuses = ApprovalStatus.all()
      assert length(statuses) > 0
    end

    test "all returned statuses can be created" do
      statuses = ApprovalStatus.all()

      for status_name <- statuses do
        assert {:ok, _status} = ApprovalStatus.new(status_name)
      end
    end
  end

  describe "draft?/1" do
    test "returns true for draft status" do
      {:ok, status} = ApprovalStatus.new("draft")
      assert ApprovalStatus.draft?(status)
    end

    test "returns false for non-draft status" do
      {:ok, status} = ApprovalStatus.new("approved")
      refute ApprovalStatus.draft?(status)
    end
  end

  describe "pending?/1" do
    test "returns true for pending_approval status" do
      {:ok, status} = ApprovalStatus.new("pending_approval")
      assert ApprovalStatus.pending?(status)
    end

    test "returns false for non-pending status" do
      {:ok, status} = ApprovalStatus.new("approved")
      refute ApprovalStatus.pending?(status)
    end
  end

  describe "approved?/1" do
    test "returns true for approved status" do
      {:ok, status} = ApprovalStatus.new("approved")
      assert ApprovalStatus.approved?(status)
    end

    test "returns false for non-approved status" do
      {:ok, status} = ApprovalStatus.new("draft")
      refute ApprovalStatus.approved?(status)
    end
  end

  describe "rejected?/1" do
    test "returns true for rejected status" do
      {:ok, status} = ApprovalStatus.new("rejected")
      assert ApprovalStatus.rejected?(status)
    end

    test "returns false for non-rejected status" do
      {:ok, status} = ApprovalStatus.new("approved")
      refute ApprovalStatus.rejected?(status)
    end
  end

  describe "archived?/1" do
    test "returns true for archived status" do
      {:ok, status} = ApprovalStatus.new("archived")
      assert ApprovalStatus.archived?(status)
    end

    test "returns false for non-archived status" do
      {:ok, status} = ApprovalStatus.new("approved")
      refute ApprovalStatus.archived?(status)
    end
  end

  describe "can_transition_to?/2" do
    test "draft can transition to pending_approval" do
      {:ok, from} = ApprovalStatus.new("draft")
      {:ok, to} = ApprovalStatus.new("pending_approval")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "draft can transition to archived" do
      {:ok, from} = ApprovalStatus.new("draft")
      {:ok, to} = ApprovalStatus.new("archived")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "draft cannot transition to approved" do
      {:ok, from} = ApprovalStatus.new("draft")
      {:ok, to} = ApprovalStatus.new("approved")
      refute ApprovalStatus.can_transition_to?(from, to)
    end

    test "pending_approval can transition to approved" do
      {:ok, from} = ApprovalStatus.new("pending_approval")
      {:ok, to} = ApprovalStatus.new("approved")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "pending_approval can transition to rejected" do
      {:ok, from} = ApprovalStatus.new("pending_approval")
      {:ok, to} = ApprovalStatus.new("rejected")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "pending_approval can transition to draft" do
      {:ok, from} = ApprovalStatus.new("pending_approval")
      {:ok, to} = ApprovalStatus.new("draft")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "approved can transition to archived" do
      {:ok, from} = ApprovalStatus.new("approved")
      {:ok, to} = ApprovalStatus.new("archived")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "approved cannot transition to draft" do
      {:ok, from} = ApprovalStatus.new("approved")
      {:ok, to} = ApprovalStatus.new("draft")
      refute ApprovalStatus.can_transition_to?(from, to)
    end

    test "rejected can transition to draft" do
      {:ok, from} = ApprovalStatus.new("rejected")
      {:ok, to} = ApprovalStatus.new("draft")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "rejected can transition to archived" do
      {:ok, from} = ApprovalStatus.new("rejected")
      {:ok, to} = ApprovalStatus.new("archived")
      assert ApprovalStatus.can_transition_to?(from, to)
    end

    test "rejected cannot transition to approved" do
      {:ok, from} = ApprovalStatus.new("rejected")
      {:ok, to} = ApprovalStatus.new("approved")
      refute ApprovalStatus.can_transition_to?(from, to)
    end

    test "archived cannot transition to any status" do
      {:ok, from} = ApprovalStatus.new("archived")

      for to_status <- ["draft", "pending_approval", "approved", "rejected"] do
        {:ok, to} = ApprovalStatus.new(to_status)
        refute ApprovalStatus.can_transition_to?(from, to)
      end
    end

    test "can transition to same status" do
      {:ok, status} = ApprovalStatus.new("draft")
      assert ApprovalStatus.can_transition_to?(status, status)
    end
  end

  describe "publicly_visible?/1" do
    test "approved is publicly visible" do
      {:ok, status} = ApprovalStatus.new("approved")
      assert ApprovalStatus.publicly_visible?(status)
    end

    test "draft is not publicly visible" do
      {:ok, status} = ApprovalStatus.new("draft")
      refute ApprovalStatus.publicly_visible?(status)
    end

    test "pending_approval is not publicly visible" do
      {:ok, status} = ApprovalStatus.new("pending_approval")
      refute ApprovalStatus.publicly_visible?(status)
    end

    test "rejected is not publicly visible" do
      {:ok, status} = ApprovalStatus.new("rejected")
      refute ApprovalStatus.publicly_visible?(status)
    end

    test "archived is not publicly visible" do
      {:ok, status} = ApprovalStatus.new("archived")
      refute ApprovalStatus.publicly_visible?(status)
    end
  end

  describe "value equality" do
    test "statuses with same value are equal" do
      {:ok, status1} = ApprovalStatus.new("draft")
      {:ok, status2} = ApprovalStatus.new("draft")

      assert status1.value == status2.value
    end

    test "statuses with different values are not equal" do
      {:ok, status1} = ApprovalStatus.new("draft")
      {:ok, status2} = ApprovalStatus.new("approved")

      assert status1.value != status2.value
    end
  end
end
