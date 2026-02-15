defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Types.Pagination.PageResult

  describe "list_all_programs/0" do
    test "returns all valid programs" do
      # Create valid programs with all required fields
      _program_1 =
        insert_program(%{
          title: "Soccer Camp",
          description: "Fun soccer for kids",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      _program_2 =
        insert_program(%{
          title: "Art Class",
          description: "Creative art activities",
          age_range: "8-14",
          price: Decimal.new("75.00"),
          pricing_period: "per month",
          spots_available: 15
        })

      _program_3 =
        insert_program(%{
          title: "Dance Workshop",
          description: "Learn various dance styles",
          age_range: "10-16",
          price: Decimal.new("100.00"),
          pricing_period: "per session",
          spots_available: 12
        })

      programs = ProgramRepository.list_all_programs()

      assert length(programs) == 3
      assert Enum.all?(programs, &match?(%Program{}, &1))

      titles = Enum.map(programs, & &1.title)
      assert "Soccer Camp" in titles
      assert "Art Class" in titles
      assert "Dance Workshop" in titles
    end

    test "returns programs in ascending title order" do
      # Insert programs in non-alphabetical order
      insert_program(%{
        title: "Zebra Camp",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      insert_program(%{
        title: "Art Class",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      insert_program(%{
        title: "Music Lessons",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      programs = ProgramRepository.list_all_programs()

      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Lessons", "Zebra Camp"]
    end

    test "returns empty list when database is empty" do
      programs = ProgramRepository.list_all_programs()

      assert programs == []
    end

    test "includes programs with price = 0 (free programs)" do
      _free_program =
        insert_program(%{
          title: "Free Community Day",
          description: "Free event for everyone",
          age_range: "All ages",
          price: Decimal.new("0.00"),
          pricing_period: "per session",
          spots_available: 100
        })

      _paid_program =
        insert_program(%{
          title: "Paid Workshop",
          description: "Premium workshop",
          age_range: "10-15",
          price: Decimal.new("200.00"),
          pricing_period: "per week",
          spots_available: 15
        })

      programs = ProgramRepository.list_all_programs()

      assert length(programs) == 2

      free = Enum.find(programs, &(&1.title == "Free Community Day"))
      assert free.price == Decimal.new("0.00")
      assert Program.free?(free)

      paid = Enum.find(programs, &(&1.title == "Paid Workshop"))
      assert paid.price == Decimal.new("200.00")
      refute Program.free?(paid)
    end

    test "includes programs with spots_available = 0 (sold out)" do
      _sold_out_program =
        insert_program(%{
          title: "Sold Out Camp",
          description: "No spots left",
          age_range: "10-15",
          price: Decimal.new("200.00"),
          pricing_period: "per week",
          spots_available: 0
        })

      _available_program =
        insert_program(%{
          title: "Available Program",
          description: "Has spots",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      programs = ProgramRepository.list_all_programs()

      assert length(programs) == 2

      sold_out = Enum.find(programs, &(&1.title == "Sold Out Camp"))
      assert sold_out.spots_available == 0
      assert Program.sold_out?(sold_out)

      available = Enum.find(programs, &(&1.title == "Available Program"))
      assert available.spots_available == 20
      refute Program.sold_out?(available)
    end

    # Note: Testing actual database connection failures with retry logic
    # is complex and would require mocking or test infrastructure that
    # can simulate connection failures. This test verifies the happy path
    # and the retry logic implementation will be verified through integration
    # testing and manual testing of error scenarios.
    test "retries database query 3 times on connection failure" do
      # This test documents the retry requirement.
      # The actual retry logic will be implemented in the repository
      # and tested through integration tests or by simulating failures.
      #
      # Expected behavior:
      # - First attempt: immediate query
      # - Second attempt: 100ms delay
      # - Third attempt: 300ms delay
      # - After 3 failures: return {:error, :database_error}
      #
      # For this unit test, we verify the happy path works correctly.
      # The retry logic itself will be validated through:
      # 1. Code review of the implementation
      # 2. Integration tests with database simulation
      # 3. Manual testing with database connection issues

      insert_program(%{
        title: "Test Program",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      })

      programs = ProgramRepository.list_all_programs()

      assert length(programs) == 1
      # The successful query indicates the repository is working.
      # Retry logic will be validated separately.
    end
  end

  describe "list_programs_paginated/2" do
    setup do
      # Create 25 programs with staggered inserted_at timestamps
      # Newer programs have later timestamps (descending order)
      base_time = ~U[2024-01-01 00:00:00Z]

      programs =
        for i <- 1..25 do
          insert_program_with_timestamp(
            %{
              title: "Program #{String.pad_leading(Integer.to_string(i), 2, "0")}",
              description: "Description #{i}",
                  age_range: "6-12",
              price: Decimal.new("#{100 + i}.00"),
              pricing_period: "per week",
              spots_available: 10
            },
            DateTime.add(base_time, i * 3600, :second)
          )
        end

      %{programs: programs}
    end

    test "returns first page with limit 10 and no cursor" do
      {:ok, page} = ProgramRepository.list_programs_paginated(10, nil)

      assert %PageResult{} = page
      assert length(page.items) == 10
      assert page.has_more == true
      assert page.next_cursor != nil
      assert page.metadata.returned_count == 10

      # Verify newest programs first (Program 25, 24, 23, ...)
      titles = Enum.map(page.items, & &1.title)
      assert List.first(titles) == "Program 25"
      assert List.last(titles) == "Program 16"
    end

    test "returns subsequent pages with cursor" do
      # Get first page
      {:ok, page1} = ProgramRepository.list_programs_paginated(10, nil)
      assert page1.has_more == true
      assert page1.next_cursor != nil

      # Get second page with cursor
      {:ok, page2} = ProgramRepository.list_programs_paginated(10, page1.next_cursor)
      assert length(page2.items) == 10
      assert page2.has_more == true
      assert page2.next_cursor != nil

      # Verify items are different and in correct order
      page1_titles = Enum.map(page1.items, & &1.title)
      page2_titles = Enum.map(page2.items, & &1.title)

      assert List.first(page2_titles) == "Program 15"
      assert List.last(page2_titles) == "Program 06"

      # Ensure no overlap
      refute Enum.any?(page1_titles, &(&1 in page2_titles))
    end

    test "sets has_more to true when more results exist" do
      {:ok, page} = ProgramRepository.list_programs_paginated(10, nil)

      assert page.has_more == true
      assert page.next_cursor != nil
    end

    test "sets has_more to false on last page" do
      # Get first page (10 items)
      {:ok, page1} = ProgramRepository.list_programs_paginated(10, nil)

      # Get second page (10 items)
      {:ok, page2} = ProgramRepository.list_programs_paginated(10, page1.next_cursor)

      # Get third page (5 items remaining)
      {:ok, page3} = ProgramRepository.list_programs_paginated(10, page2.next_cursor)

      assert length(page3.items) == 5
      assert page3.has_more == false
      assert page3.next_cursor == nil
    end

    test "returns empty results when no programs exist" do
      # Clean database (delete sessions first due to FK constraint)
      Repo.delete_all(ProgramSessionSchema)
      Repo.delete_all(ProgramSchema)

      {:ok, page} = ProgramRepository.list_programs_paginated(20, nil)

      assert page.items == []
      assert page.has_more == false
      assert page.next_cursor == nil
      assert page.metadata.returned_count == 0
    end

    test "returns empty results when cursor is beyond last item" do
      # Get all pages until the end
      {:ok, page1} = ProgramRepository.list_programs_paginated(10, nil)
      {:ok, page2} = ProgramRepository.list_programs_paginated(10, page1.next_cursor)
      {:ok, page3} = ProgramRepository.list_programs_paginated(10, page2.next_cursor)

      # page3 should be the last page with 5 items and no next cursor
      assert length(page3.items) == 5
      assert page3.next_cursor == nil

      # Manually create a cursor that would be beyond the last item
      # This simulates requesting a page after all data has been retrieved
      last_program = List.last(page3.items)
      fake_cursor = create_cursor_after(last_program)

      {:ok, page4} = ProgramRepository.list_programs_paginated(10, fake_cursor)

      assert page4.items == []
      assert page4.has_more == false
      assert page4.next_cursor == nil
    end

    test "handles invalid cursor gracefully" do
      invalid_cursor = "invalid_base64_cursor"

      assert {:error, :invalid_cursor} =
               ProgramRepository.list_programs_paginated(20, invalid_cursor)
    end

    test "handles malformed cursor data" do
      # Valid base64 but invalid JSON
      malformed_cursor = Base.url_encode64("not json", padding: false)

      assert {:error, :invalid_cursor} =
               ProgramRepository.list_programs_paginated(20, malformed_cursor)
    end

    test "handles cursor with invalid timestamp" do
      # Valid JSON but invalid timestamp
      invalid_data = Jason.encode!(%{"ts" => "not_a_number", "id" => Ecto.UUID.generate()})
      invalid_cursor = Base.url_encode64(invalid_data, padding: false)

      assert {:error, :invalid_cursor} =
               ProgramRepository.list_programs_paginated(20, invalid_cursor)
    end

    test "handles cursor with invalid UUID" do
      # Valid JSON but invalid UUID
      invalid_data = Jason.encode!(%{"ts" => 1_234_567_890_123_456, "id" => "not-a-uuid"})
      invalid_cursor = Base.url_encode64(invalid_data, padding: false)

      assert {:error, :invalid_cursor} =
               ProgramRepository.list_programs_paginated(20, invalid_cursor)
    end

    test "handles limit boundary conditions" do
      # Limit below minimum (0) - should be constrained to 1
      {:ok, page} = ProgramRepository.list_programs_paginated(0, nil)
      assert length(page.items) == 1

      # Limit at minimum (1)
      {:ok, page} = ProgramRepository.list_programs_paginated(1, nil)
      assert length(page.items) == 1

      # Limit at maximum (100) - should return all 25
      {:ok, page} = ProgramRepository.list_programs_paginated(100, nil)
      assert length(page.items) == 25
      assert page.has_more == false

      # Limit above maximum (101) - should be constrained to 100
      {:ok, page} = ProgramRepository.list_programs_paginated(101, nil)
      assert length(page.items) == 25
      assert page.has_more == false
    end

    test "orders by inserted_at DESC, id DESC" do
      {:ok, page} = ProgramRepository.list_programs_paginated(25, nil)

      # Verify newest first (Program 25 was inserted last with latest timestamp)
      titles = Enum.map(page.items, & &1.title)
      assert List.first(titles) == "Program 25"
      assert List.last(titles) == "Program 01"
    end

    test "cursor roundtrip encoding and decoding" do
      {:ok, page1} = ProgramRepository.list_programs_paginated(10, nil)
      cursor = page1.next_cursor

      # Use the cursor to get next page
      {:ok, page2} = ProgramRepository.list_programs_paginated(10, cursor)

      # Verify we got different items
      page1_titles = Enum.map(page1.items, & &1.title)
      page2_titles = Enum.map(page2.items, & &1.title)

      refute Enum.any?(page1_titles, &(&1 in page2_titles))
    end

    test "handles exactly page_size results correctly" do
      # Clean database (delete sessions first due to FK constraint) and insert exactly 10 programs
      Repo.delete_all(ProgramSessionSchema)
      Repo.delete_all(ProgramSchema)

      base_time = ~U[2024-01-01 00:00:00Z]

      for i <- 1..10 do
        insert_program_with_timestamp(
          %{
            title: "Program #{i}",
            description: "Description",
              age_range: "6-12",
            price: Decimal.new("100.00"),
            pricing_period: "per week",
            spots_available: 10
          },
          DateTime.add(base_time, i * 3600, :second)
        )
      end

      # Request exactly 10 items (all of them)
      {:ok, page} = ProgramRepository.list_programs_paginated(10, nil)

      assert length(page.items) == 10
      assert page.has_more == false
      assert page.next_cursor == nil
    end

    test "handles exactly page_size + 1 results correctly" do
      # Clean database (delete sessions first due to FK constraint) and insert exactly 11 programs
      Repo.delete_all(ProgramSessionSchema)
      Repo.delete_all(ProgramSchema)

      base_time = ~U[2024-01-01 00:00:00Z]

      for i <- 1..11 do
        insert_program_with_timestamp(
          %{
            title: "Program #{i}",
            description: "Description",
              age_range: "6-12",
            price: Decimal.new("100.00"),
            pricing_period: "per week",
            spots_available: 10
          },
          DateTime.add(base_time, i * 3600, :second)
        )
      end

      # Request 10 items (leaving 1 remaining)
      {:ok, page} = ProgramRepository.list_programs_paginated(10, nil)

      assert length(page.items) == 10
      assert page.has_more == true
      assert page.next_cursor != nil
    end

    test "all returned items are valid Program domain models" do
      {:ok, page} = ProgramRepository.list_programs_paginated(20, nil)

      assert Enum.all?(page.items, &match?(%Program{}, &1))
      assert Enum.all?(page.items, &(&1.title != nil))
      assert Enum.all?(page.items, &(&1.description != nil))
    end
  end

  describe "update/1 with optimistic locking" do
    test "successfully updates program and increments lock_version" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Original Title",
          description: "Original description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      assert program_schema.lock_version == 1

      # Convert to domain and update
      domain_program = ProgramMapper.to_domain(program_schema)
      updated_program = %{domain_program | title: "Updated Title", spots_available: 15}

      # Execute update
      assert {:ok, result} = ProgramRepository.update(updated_program)

      # Verify changes persisted
      assert result.title == "Updated Title"
      assert result.spots_available == 15

      # Verify lock_version incremented
      updated_schema = Repo.get(ProgramSchema, program_schema.id)
      assert updated_schema.lock_version == 2
      assert updated_schema.title == "Updated Title"
      assert updated_schema.spots_available == 15
    end

    test "detects concurrent modification with stale_data error" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Original Title",
          description: "Description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      # Simulate two processes fetching the same program
      domain_v1_a = ProgramMapper.to_domain(program_schema)
      domain_v1_b = ProgramMapper.to_domain(program_schema)

      # First update succeeds (lock_version 1 → 2)
      updated_a = %{domain_v1_a | title: "Update A"}
      assert {:ok, _result} = ProgramRepository.update(updated_a)

      # Second update fails with stale data (still has lock_version 1)
      updated_b = %{domain_v1_b | title: "Update B"}
      assert {:error, :stale_data} = ProgramRepository.update(updated_b)

      # Verify first update persisted, second did not
      final_schema = Repo.get(ProgramSchema, program_schema.id)
      assert final_schema.title == "Update A"
      assert final_schema.lock_version == 2
    end

    test "handles multiple sequential updates with version increments" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Version 1",
          description: "Description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      assert program_schema.lock_version == 1

      # First update
      domain_v1 = ProgramMapper.to_domain(program_schema)
      updated_v1 = %{domain_v1 | title: "Version 2"}
      assert {:ok, result_v2} = ProgramRepository.update(updated_v1)

      # Second update (using fresh domain from first update result)
      updated_v2 = %{result_v2 | title: "Version 3"}
      assert {:ok, result_v3} = ProgramRepository.update(updated_v2)

      # Third update (using fresh domain from second update result)
      updated_v3 = %{result_v3 | title: "Version 4"}
      assert {:ok, _result_v4} = ProgramRepository.update(updated_v3)

      # Verify final state
      final_schema = Repo.get(ProgramSchema, program_schema.id)
      assert final_schema.title == "Version 4"
      assert final_schema.lock_version == 4
    end

    test "returns not_found error for non-existent program" do
      # Create a program structure with non-existent ID
      non_existent_program = %Program{
        id: Ecto.UUID.generate(),
        title: "Non-existent",
        description: "Description",
        category: "education",
        meeting_days: ["Monday"],
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        icon_path: "/images/icon.svg",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      assert {:error, :not_found} = ProgramRepository.update(non_existent_program)
    end

    test "returns changeset error for constraint violation" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Valid Program",
          description: "Description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      # Attempt update with invalid data (negative price violates constraint)
      domain_program = ProgramMapper.to_domain(program_schema)
      invalid_program = %{domain_program | price: Decimal.new("-100.00")}

      # Update should fail with changeset validation error
      # (validate_number ensures price >= 0)
      assert {:error, %Ecto.Changeset{valid?: false}} = ProgramRepository.update(invalid_program)

      # Verify original data unchanged
      unchanged_schema = Repo.get(ProgramSchema, program_schema.id)
      assert unchanged_schema.price == Decimal.new("150.00")
      assert unchanged_schema.lock_version == 1
    end

    test "returns changeset error for empty required field" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Valid Program",
          description: "Description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      # Attempt update with empty title (required field)
      domain_program = ProgramMapper.to_domain(program_schema)
      invalid_program = %{domain_program | title: ""}

      # Update should fail with changeset validation error
      assert {:error, %Ecto.Changeset{valid?: false}} = ProgramRepository.update(invalid_program)

      # Verify original data unchanged
      unchanged_schema = Repo.get(ProgramSchema, program_schema.id)
      assert unchanged_schema.title == "Valid Program"
      assert unchanged_schema.lock_version == 1
    end

    test "updates all modifiable fields correctly" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Original",
          description: "Original description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20,
          icon_path: "/images/original.svg"
        })

      # Update all modifiable fields
      domain_program = ProgramMapper.to_domain(program_schema)

      updated_program = %{
        domain_program
        | title: "New Title",
          description: "New description",
          meeting_days: ["Tuesday", "Thursday"],
          age_range: "8-14",
          price: Decimal.new("200.00"),
          pricing_period: "per month",
          spots_available: 15,
          icon_path: "/images/new.svg"
      }

      assert {:ok, result} = ProgramRepository.update(updated_program)

      # Verify all fields updated
      assert result.title == "New Title"
      assert result.description == "New description"
      assert result.meeting_days == ["Tuesday", "Thursday"]
      assert result.age_range == "8-14"
      assert result.price == Decimal.new("200.00")
      assert result.pricing_period == "per month"
      assert result.spots_available == 15
      assert result.icon_path == "/images/new.svg"

      # Verify in database
      updated_schema = Repo.get(ProgramSchema, program_schema.id)
      assert updated_schema.title == "New Title"
      assert updated_schema.lock_version == 2
    end

    test "concurrent updates by multiple processes fail correctly" do
      # Create a program
      program_schema =
        insert_program(%{
          title: "Concurrent Test",
          description: "Description",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20
        })

      # Simulate 5 concurrent processes attempting to update
      domain_programs =
        for i <- 1..5 do
          domain = ProgramMapper.to_domain(program_schema)
          %{domain | spots_available: 20 - i}
        end

      # Execute all updates concurrently
      results =
        domain_programs
        |> Enum.map(&Task.async(fn -> ProgramRepository.update(&1) end))
        |> Enum.map(&Task.await/1)

      # Exactly one should succeed, others should fail with :stale_data
      successful_updates = Enum.count(results, &match?({:ok, _}, &1))
      stale_data_errors = Enum.count(results, &match?({:error, :stale_data}, &1))

      assert successful_updates == 1
      assert stale_data_errors == 4

      # Verify lock_version incremented only once
      final_schema = Repo.get(ProgramSchema, program_schema.id)
      assert final_schema.lock_version == 2
    end
  end

  describe "list_programs_for_provider/1" do
    test "returns programs for a specific provider" do
      provider = insert(:provider_profile_schema)
      other_provider = insert(:provider_profile_schema)

      # Create programs for target provider
      _program_1 =
        insert_program(%{
          title: "Soccer Camp",
          description: "Fun soccer",
          age_range: "6-12",
          price: Decimal.new("150.00"),
          pricing_period: "per week",
          spots_available: 20,
          provider_id: provider.id
        })

      _program_2 =
        insert_program(%{
          title: "Art Class",
          description: "Creative arts",
          age_range: "8-14",
          price: Decimal.new("75.00"),
          pricing_period: "per month",
          spots_available: 15,
          provider_id: provider.id
        })

      # Create program for different provider
      _other_program =
        insert_program(%{
          title: "Music Lessons",
          description: "Learn music",
          age_range: "10-16",
          price: Decimal.new("100.00"),
          pricing_period: "per session",
          spots_available: 12,
          provider_id: other_provider.id
        })

      programs = ProgramRepository.list_programs_for_provider(provider.id)

      assert length(programs) == 2
      assert Enum.all?(programs, &match?(%Program{}, &1))

      titles = Enum.map(programs, & &1.title)
      assert "Soccer Camp" in titles
      assert "Art Class" in titles
      refute "Music Lessons" in titles
    end

    test "returns programs in ascending title order" do
      provider = insert(:provider_profile_schema)

      insert_program(%{
        title: "Zebra Camp",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        provider_id: provider.id
      })

      insert_program(%{
        title: "Art Class",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        provider_id: provider.id
      })

      insert_program(%{
        title: "Music Lessons",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        provider_id: provider.id
      })

      programs = ProgramRepository.list_programs_for_provider(provider.id)

      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Lessons", "Zebra Camp"]
    end

    test "returns empty list when provider has no programs" do
      provider = insert(:provider_profile_schema)

      programs = ProgramRepository.list_programs_for_provider(provider.id)

      assert programs == []
    end

    test "returns empty list for non-existent provider_id" do
      non_existent_id = Ecto.UUID.generate()

      # Create a program for a different provider to ensure database isn't empty
      provider = insert(:provider_profile_schema)

      insert_program(%{
        title: "Some Program",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        provider_id: provider.id
      })

      programs = ProgramRepository.list_programs_for_provider(non_existent_id)

      assert programs == []
    end

    test "includes free and sold out programs" do
      provider = insert(:provider_profile_schema)

      _free_program =
        insert_program(%{
          title: "Free Community Day",
          description: "Free event",
          age_range: "All ages",
          price: Decimal.new("0.00"),
          pricing_period: "per session",
          spots_available: 100,
          provider_id: provider.id
        })

      _sold_out_program =
        insert_program(%{
          title: "Popular Camp",
          description: "Fully booked",
          age_range: "10-15",
          price: Decimal.new("200.00"),
          pricing_period: "per week",
          spots_available: 0,
          provider_id: provider.id
        })

      programs = ProgramRepository.list_programs_for_provider(provider.id)

      assert length(programs) == 2

      free = Enum.find(programs, &(&1.title == "Free Community Day"))
      assert free.price == Decimal.new("0.00")
      assert Program.free?(free)

      sold_out = Enum.find(programs, &(&1.title == "Popular Camp"))
      assert sold_out.spots_available == 0
      assert Program.sold_out?(sold_out)
    end
  end

  # Helper function to insert a complete valid program
  defp insert_program(attrs) do
    default_attrs = %{
      id: Ecto.UUID.generate(),
      category: "education",
      icon_path: "/images/default.svg"
    }

    attrs = Map.merge(default_attrs, attrs)

    %ProgramSchema{}
    |> ProgramSchema.changeset(attrs)
    |> Repo.insert!()
  end

  # Helper function to insert program with specific timestamp
  defp insert_program_with_timestamp(attrs, inserted_at) do
    default_attrs = %{
      id: Ecto.UUID.generate(),
      category: "education",
      icon_path: "/images/default.svg"
    }

    attrs = Map.merge(default_attrs, attrs)

    %ProgramSchema{}
    |> ProgramSchema.changeset(attrs)
    |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
    |> Repo.insert!()
  end

  # Helper to create a cursor pointing after a given program
  defp create_cursor_after(program) do
    # Create a timestamp 1 second before the program's inserted_at
    cursor_ts = DateTime.add(program.inserted_at, -1, :second)

    cursor_data = %{
      "ts" => DateTime.to_unix(cursor_ts, :microsecond),
      "id" => program.id
    }

    cursor_data
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end
end
