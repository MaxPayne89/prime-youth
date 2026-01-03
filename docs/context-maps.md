# Context Maps for Klass Hero Application

This document contains context maps for the Klass Hero bounded contexts, showing high-level domain relationships and interactions.

**Scope**: Maps show both **current state (as-is)** and **planned state (to-be)** with clear visual distinction:
- **Solid lines/boxes**: Currently implemented
- **Dashed lines/boxes**: Planned but not implemented

---

## 1. Strategic Context Map

This map shows all bounded contexts and their relationships at a strategic level.

```mermaid
flowchart TB
    subgraph core [Core Domain]
        PC[Program Catalog]
        EN[Enrollment]
    end

    subgraph supporting [Supporting Domain]
        PA[Participation]
        PT[Progress Tracking]
        RR[Review & Rating]
        CM[Community]
    end

    subgraph generic [Generic Domain]
        AC[Accounts]
        ID[Identity]
        SP[Support]
    end

    %% Identity relationships
    AC -->|identity| ID

    %% Core domain flows
    PC -->|supplies programs| EN
    ID -->|supplies children| EN
    EN -->|enrollments| PA

    %% Supporting relationships
    PA -->|participation data| PT
    ID -->|child context| PA
    PC -->|program context| RR
    ID -->|reviewer context| RR
    ID -->|author context| CM

    %% Missing contexts (dashed)
    PT -.->|not implemented| PC
    RR -.->|not implemented| PC
```

**Legend:**
- **Solid arrows**: Implemented relationships
- **Dashed arrows**: Planned but not implemented
- **Core Domain**: Essential business differentiators
- **Supporting Domain**: Supports core but not differentiating
- **Generic Domain**: Commodity functionality

---

## 2. Identity & Profile Context Map

Shows how user identity flows through the consolidated Identity context.

```mermaid
flowchart LR
    subgraph accounts [Accounts Context]
        U[User]
        UT[UserToken]
    end

    subgraph identity [Identity Context]
        PP[Parent Profile]
        PV[Provider Profile]
        CH[Child]
    end

    U -->|"identity_id (correlation)"| PP
    U -->|"identity_id (correlation)"| PV
    PP -->|"manages"| CH

    identity -.->|"Shared Kernel: EventPublisher"| events((Domain Events))
```

**Relationship Types:**
- **Accounts -> Identity**: Conformist (Identity conforms to Accounts identity)
- **Consolidated**: Parent profiles, provider profiles, and child management unified in single context

---

## 3. Program Lifecycle Context Map

Shows the journey from program discovery to participation.

```mermaid
flowchart LR
    subgraph discovery [Discovery Phase]
        PC[Program Catalog]
    end

    subgraph enrollment [Enrollment Phase]
        EN[Enrollment]
        FC[Fee Calculation]
    end

    subgraph participation [Participation Phase]
        PA[Participation]
        PS[Program Sessions]
        PR[Participation Records]
    end

    subgraph identity [Identity Context]
        CH[Children]
    end

    PC -->|"Supplier: program details"| EN
    FC -->|"part of"| EN
    identity -->|"Supplier: child selection"| EN
    EN -->|"creates"| PS
    PS -->|"records"| PR
    identity -->|"ACL: ChildNameResolver"| PA
```

**Relationship Types:**
- **Program Catalog -> Enrollment**: Supplier (upstream)
- **Identity -> Enrollment**: Supplier (upstream)
- **Identity -> Participation**: Anti-Corruption Layer (ChildNameResolver adapter)

---

## 4. Participation Context Detail Map

Shows the internal structure and cross-context dependencies.

```mermaid
flowchart TB
    subgraph participation [Participation Context]
        subgraph domain [Domain Layer]
            PSM[ProgramSession]
            PRM[ParticipationRecord]
        end

        subgraph ports [Ports]
            PSR[SessionRepository Port]
            PRR[ParticipationRepository Port]
            CNR[ChildNameResolver Port]
        end

        subgraph usecases [Use Cases]
            LS[ListSessions]
            SS[StartSession]
            RCI[RecordCheckIn]
            RCO[RecordCheckOut]
            BCI[BulkCheckIn]
        end
    end

    subgraph identity [Identity Context]
        CHD[Child Domain]
    end

    usecases --> ports
    ports --> domain
    CNR -->|"ACL"| CHD
```

**Pattern**: Anti-Corruption Layer (ACL) protects Participation from Identity context changes.

---

## 5. Social Features Context Map

Shows the Community context and its relationships.

```mermaid
flowchart TB
    subgraph community [Community Context]
        POST[Post]
        CMT[Comment]
        LIKE[Like Toggle]
    end

    subgraph identity [Identity Context]
        AUTH[Author Identity]
    end

    subgraph events [Shared Kernel]
        EP[EventPublisher]
        CE[CommunityEvents]
    end

    AUTH -->|"author context"| POST
    POST -->|"contains"| CMT
    POST -->|"has"| LIKE
    POST -.->|"publishes"| CE
    CE -->|"via"| EP
```

**Status**: In-memory only, no database persistence.

---

## 6. Identified Gaps

### Missing Contexts (Documented but Not Implemented)

```mermaid
flowchart TB
    subgraph missing [Not Implemented]
        PT[Progress Tracking]
        RR[Review & Rating]
    end

    subgraph exists [Implemented]
        PA[Participation]
        PC[Program Catalog]
        ID[Identity]
    end

    PA -.->|"should feed"| PT
    PC -.->|"should be reviewed by"| RR
    ID -.->|"reviewer identity"| RR
```

### Implementation Status

| Context | Status | Notes |
|---------|--------|-------|
| Accounts | Complete | Standard Phoenix auth |
| Program Catalog | Complete | Full DDD implementation |
| Identity | Complete | Consolidated Parenting + Providing + Family |
| Participation | Complete | Renamed from Attendance, full DDD with ACL |
| Enrollment | Skeleton | Only fee calculation |
| Community | Partial | Renamed from Highlights, in-memory only |
| Support | Basic | Contact form only |
| Progress Tracking | Not Started | Documented only |
| Review & Rating | Not Started | Documented only |

---

## 7. Context Relationship Summary

| Upstream | Downstream | Relationship Type | Status |
|----------|------------|-------------------|--------|
| Accounts | Identity | Conformist | Implemented |
| Program Catalog | Enrollment | Supplier | Partial |
| Identity | Enrollment | Supplier | Partial |
| Identity | Participation | ACL | Implemented |
| Participation | Progress Tracking | Supplier | Not Started |
| Program Catalog | Review & Rating | Supplier | Not Started |
| Identity | Review & Rating | Supplier | Not Started |
| Identity | Community | Supplier | Implemented |

---

## 8. Consolidation Status

### Previous State: 9 Implemented Contexts

The application previously had 9 bounded contexts (Accounts, Parenting, Providing, Family, Attendance, Highlights, Program Catalog, Enrollment, Support), with 2 additional contexts planned but never implemented (Progress Tracking, Review & Rating).

### Current State: 7 Contexts ✅

```mermaid
flowchart TB
    subgraph core [Core Domain]
        PC[Program Catalog]
        EN[Enrollment]
    end

    subgraph identity [Identity Context - Consolidated]
        ID["Identity\n(Parent + Provider + Child)"]
    end

    subgraph participation [Participation Context - Renamed]
        PA["Participation\n(Attendance)"]
    end

    subgraph community [Community Context - Renamed]
        CM["Community\n(Highlights)"]
    end

    subgraph generic [Generic Domain]
        AC[Accounts]
        SP[Support]
    end
```

**Consolidation Achievements:**
1. **Identity Context**: Successfully merged Parenting + Providing + Family contexts - all manage user profiles and identity
2. **Participation Context**: Renamed from Attendance for better semantic clarity
3. **Community Context**: Renamed from Highlights for clearer domain purpose

**Future Opportunities:**
- **Participation + Progress**: When Progress Tracking is implemented, consider merging with Participation
- **Community + Reviews**: When Review & Rating is implemented, consider merging with Community

---

## Open Questions

1. **Progress Tracking**: Planned, would depend on Participation data - consider merging with Participation when implemented
2. **Review & Rating**: Planned, would depend on Program Catalog and Identity - consider merging with Community when implemented
3. **Enrollment Completion**: Currently skeletal (fee calculation only) - needs full implementation

---

## References

- `docs/domain-stories.md` - Business domain understanding
- `lib/klass_hero/` - Implementation of bounded contexts
