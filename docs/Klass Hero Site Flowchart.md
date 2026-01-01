flowchart TB
 subgraph Guest_Flow["Public / Guest Experience"]
        A["About Page"]
        L["Landing Page"]
        PP["Public Programs List"]
        PR["Parents Resources - Blog"]
        VR["Provider Resources - Blog"]
        PPD["Public Program Detail"]
        Login{"Login / Sign Up"}
        Signup{"Sign Up"}
  end
 subgraph Parent_Portal["Authenticated Parent Flow"]
        PDash["Parent Dashboard"]
        P_Exp["Explore Programs"]
        P_Plan["Planner / Calendar (paid)"]
        P_Comm["Community Feed & Jobs"]
        P_Chat["Chat & Video Calls"]
        P_Set["Account Settings"]
        P_Book["Book Activity"]
  end
 subgraph Provider_Portal["Authenticated Provider Flow"]
        VDash["Provider Overview"]
        V_Team["Provider Profiles"]
        V_Prog["Program Inventory"]
        V_Fin["Finance: Expenses & Invoices"]
        V_Chat["Messages & Broadcasts"]
        V_Anly["Analytics & Growth"]
        V_Manage["Manage Rosters"]
        V_CreateProg["Create Program"]
        V_PublishPrograms["Publish Program"]
        V_AssignPrograms["Assign Program to Profiles / Team"]
  end
 subgraph Booking_Flow["Booking Flow (Parent)"]
        Booking_Start["Start Booking (from Landing, Programs, or Parent Book CTA)"]
        Auth_Check{"Authenticated?"}
        Credits_Check{"Enough credits?"}
        Upgrade["Upgrade Account or Pay Extra Fee"]
        Payment_Upgrade["Payment: Upgrade / Extra Fee"]
        Registration_Form["Registration Form (fields required by program)"]
        Review_Submit["Parent Review & Submit"]
        BookingType{"Program is Instant Book?"}
        Booking_Review["Booking Review & Confirmation"]
        Payment["Payment"]
        PostPayment["Registration Confirmation & Invoice (sent to Provider & Parent)"]
        ByRequestNotify["Send notification email to Provider"]
        ParentConfirmEmail["Confirmation email to Parent (request received)"]
        Booking_Pending["Booking Pending / Awaiting Provider Approval"]
        Chat_Node["Chat Provider (active accounts only)"]
  end
 subgraph SignUp_Flow["Sign Up Flow"]
        P_SignStart["Parent Sign Up Start"]
        P_Contact["Contact Details (email, phone, address)"]
        P_ParentProfile["Parent Profile (name, preferred contact)"]
        P_ChildAdd["Add Child(ren): name, DOB"]
        P_Emergency["Emergency Contact"]
        P_Medical["Medical Info / Allergies / Needs"]
        P_Consents["Photo/Media Consent & Marketing opt-in"]
        P_Terms["Accept Terms & Conditions / Privacy Policy"]
        P_VerifyEmail["Email Verification"]
        P_AccountChoose{"Choose Account Type (Free / Paid / Business Family Plan)"}
        P_AccountActive["Account Active (full features)"]
        P_AccountFree["Free Account (limited: no chat, limited credits)"]
        V_SignStart["Provider Sign Up Start"]
        V_Contact["Provider Contact Details"]
        V_Type{"Sign up as Individual or Business?"}
        V_IDVerify["ID Verification (gov ID upload)"]
        V_BackCheck["Police / Background Check Upload"]
        V_Badges["Optional: Add Badges & Certificates (First Aid, Safeguarding, Degrees)"]
        V_Experience["Select Experience Levels by Category: Art / Sports / Life Skills / Academic (new / 5yrs / 10yrs / >20yrs)"]
        V_BusinessDocs["Business Registration / VAT (if Business Plan)"]
        V_VettingPending["Vetting Pending (docs review)"]
        V_Approved["Provider Approved (vetting passed)"]
        V_Rejected["Provider Rejected (feedback sent)"]
        V_CreateProfiles["Create / Link Profile(s) (personal or pro profile)"]
        V_ReviewProfile["Review & Publish Profile"]
        V_CreateBusiness["Create Business Account (business plan)"]
        V_CreateProfiles_Biz["Create / Link Pro Profiles under Business"]
  end
    V_Approved --> V_Approved_FP["Approved → Free / Professional flow"] & V_Approved_Biz["Approved → Business flow"]
    V_Approved_FP --> V_CreateProfiles
    V_CreateProfiles --> V_ReviewProfile
    V_ReviewProfile -- Profile published --> VDash
    V_CreateProfiles -- If Professional: optionally link one other pro account --> V_LinkOtherPro["Link one other pro account (optional)"]
    V_LinkOtherPro --> V_ReviewProfile
    V_Approved_Biz --> V_CreateBusiness
    V_CreateBusiness --> V_CreateProfiles_Biz & V_BusinessDocs
    V_CreateProfiles_Biz --> V_ReviewProfile & V_AssignPrograms
    VDash --> V_CreateProg & V_Team & V_Prog & V_Fin & V_Chat & V_Anly
    V_CreateProg --> V_Prog & V_PublishPrograms
    V_PublishPrograms --> V_Prog & V_AssignPrograms
    V_AssignPrograms --> V_Manage
    L --> A & PP & PR & VR & Login & Signup
    PP --> PPD
    PPD -- CTA: Register to Book --> Login
    PPD -- CTA: Sign Up --> Signup
    Login -- Role: Parent --> PDash
    Login -- Role: Provider --> VDash
    Signup --> P_SignStart & V_SignStart
    P_SignStart --> P_Contact
    P_Contact --> P_ParentProfile
    P_ParentProfile --> P_ChildAdd
    P_ChildAdd --> P_Emergency
    P_Emergency --> P_Medical
    P_Medical --> P_Consents
    P_Consents --> P_Terms
    P_Terms --> P_VerifyEmail
    P_VerifyEmail --> P_AccountChoose
    P_AccountChoose -- Free --> P_AccountFree
    P_AccountChoose -- Paid / Family Plan --> P_AccountActive
    P_VerifyEmail -- Success --> P_AccountActive
    P_VerifyEmail -- Pending --> P_AccountFree
    P_AccountActive --> PDash
    P_AccountFree --> PDash
    V_SignStart --> V_Contact
    V_Contact --> V_Type
    V_Type -- Individual --> V_IDVerify & V_BackCheck
    V_Type -- Business --> V_IDVerify & V_BackCheck & V_BusinessDocs
    V_IDVerify --> V_VettingPending
    V_BackCheck --> V_VettingPending
    V_BusinessDocs --> V_VettingPending
    V_VettingPending -- Approved --> V_Approved
    V_VettingPending -- Rejected --> V_Rejected
    V_Rejected --> VDash
    Booking_Start --> Auth_Check
    Auth_Check -- No --> Login & Signup
    Auth_Check -- Yes --> Credits_Check
    Credits_Check -- No --> Upgrade
    Upgrade --> Payment_Upgrade
    Payment_Upgrade --> Registration_Form
    Credits_Check -- Yes --> Registration_Form
    Registration_Form --> Review_Submit
    Review_Submit --> BookingType
    BookingType -- Yes (Instant) --> Booking_Review
    Booking_Review --> Payment
    Payment --> PostPayment
    BookingType -- No (By request) --> ByRequestNotify
    ByRequestNotify --> ParentConfirmEmail
    ParentConfirmEmail --> Booking_Pending
    PostPayment --> PDash
    Registration_Form -. Can message provider (active accounts only) .-> Chat_Node
    Booking_Review -. Can message provider (active accounts only) .-> Chat_Node
    ByRequestNotify -. Can message provider (active accounts only) .-> Chat_Node
    Payment -. Can message provider (active accounts only) .-> Chat_Node
    P_Chat -- Access overall chat hub --> Chat_Node
    Chat_Node --> V_Chat
    Booking_Pending -- Provider accepts --> Payment
    Booking_Pending -- Provider declines --> PDash
    PDash --> P_Exp & P_Plan & P_Comm & P_Chat & P_Set
    P_Exp --> P_Book
    V_Prog --> V_Manage & V_CreateProg
    P_Chat <--> V_Chat
    P_Comm -- Post Job --> V_Chat
    V_Badges <--> V_Experience
    V_Experience <--> V_CreateProfiles
    V_CreateProfiles_Biz <--> V_Team
    V_Manage --> V_Chat
    n1["Provider Profiles"]

    n1@{ shape: rounded}
     A:::guest
     L:::guest
     PP:::guest
     PR:::guest
     VR:::guest
     PPD:::guest
     Login:::action
     Signup:::action
     PDash:::parent
     P_Exp:::parent
     P_Plan:::parent
     P_Comm:::parent
     P_Chat:::parent
     P_Set:::parent
     P_Book:::parent
     VDash:::provider
     V_Team:::provider
     V_Prog:::provider
     V_Fin:::provider
     V_Chat:::provider
     V_Anly:::provider
     V_Manage:::provider
     V_CreateProg:::provider
     V_PublishPrograms:::provider
     V_AssignPrograms:::provider
    classDef guest fill:#FFEAC9,stroke:#333,stroke-width:2px,color:#000
    classDef parent fill:#0FC3FF,stroke:#333,stroke-width:2px,color:#000
    classDef provider fill:#FFFF36,stroke:#333,stroke-width:2px,color:#000
    classDef action fill:#fff,stroke-dasharray: 5 5
