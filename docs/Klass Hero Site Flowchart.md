flowchart TB
  %% === Existing Top-level Areas ===
  subgraph Guest_Flow["Public / Guest Experience"]
        A("About Page")
        L("Landing Page")
        PP("Public Programs List")
        PR("Parents Resources - Blog")
        VR("Provider Resources - Blog")
        PPD("Public Program Detail")
        Login{"Login / Sign Up"}
        Signup{"Sign Up"}
  end

  subgraph Parent_Portal["Authenticated Parent Flow"]
        PDash("Parent Dashboard")
        P_Exp("Explore Programs")
        P_Plan("Planner / Calendar (paid)")
        P_Comm("Community Feed & Jobs")
        P_Chat("Chat & Video Calls")
        P_Set("Account Settings")
        P_Book["Book Activity"]
  end

  subgraph Provider_Portal["Authenticated Provider Flow"]
        VDash("Provider Overview")
        V_Team("Provider Profiles")
        V_Prog("Program Inventory")
        V_Fin("Finance: Expenses & Invoices")
        V_Chat("Messages & Broadcasts")
        V_Anly("Analytics & Growth")
        V_Manage["Manage Rosters"]
        V_CreateProg("Create Program")
  end

  %% === Booking Flow (Parent) ===
  subgraph Booking_Flow["Booking Flow (Parent)"]
        Booking_Start("Start Booking (From Landing, Programs, or Parent Book CTA)")
        Auth_Check{"Authenticated?"}
        Credits_Check{"Enough credits?"}
        Upgrade("Upgrade Account or Pay Extra Fee")
        Payment_Upgrade("Payment: Upgrade / Extra Fee")
        Registration_Form("Registration Form (fields required by program)")
        Review_Submit("Parent Review & Submit")
        BookingType{"Program is Instant Book?"}
        Booking_Review("Booking Review & Confirmation")
        Payment("Payment")
        PostPayment("Registration Confirmation & Invoice Sent to Provider & Parent")
        ByRequestNotify("Send notification email to Provider")
        ParentConfirmEmail("Confirmation email to Parent (booking request received)")
        Booking_Pending("Booking Pending / Awaiting Provider Approval")
        Chat_Node("Chat Provider (Active accounts only)")
  end

  %% === Sign Up Flows ===
  subgraph SignUp_Flow["Sign Up Flow"]
    %% Parent sign up
    P_SignStart("Parent Sign Up Start")
    P_Contact("Contact Details (email, phone, address)")
    P_ParentProfile("Parent Profile (name, preferred contact)")
    P_ChildAdd("Add Child(ren): Name, DOB")
    P_Emergency("Emergency Contact")
    P_Medical("Medical Info / Allergies / Needs")
    P_Consents("Photo/Media Consent & Marketing Opt-in")
    P_Terms("Accept Terms & Conditions / Privacy Policy")
    P_VerifyEmail("Email Verification")
    P_AccountChoose{"Choose Account Type (Free / Paid / Business Family Plan)"}
    P_AccountActive("Account Active (full features)")
    P_AccountFree("Free Account (limited: no chat, limited credits)")

    %% Provider sign up
    V_SignStart("Provider Sign Up Start")
    V_Contact("Provider Contact Details")
    V_Type{"Sign up as Individual or Business?"}
    V_IDVerify("ID Verification (gov ID upload)")
    V_BackCheck("Police / Background Check Upload")
    V_Badges("Optional: Add Badges & Certificates (First Aid, Safeguarding, Degrees)")
    V_Experience("Select Experience Levels by Category: Art / Sports / Life Skills / Academic (new / 5yrs / 10yrs / >20yrs)")
    V_BusinessDocs("Business Registration / VAT (if Business Plan)")
    V_VettingPending("Vetting Pending (docs review)")
    V_Approved("Provider Approved - Full Listing")
    V_Rejected("Provider Rejected - Feedback Sent")
    V_CreateProfiles("Create / Link Profiles to Business")
    V_ProfileLimitCheck{"Professional Provider? (if Professional: max 1 additional profile)"}
    V_AssignPrograms("Assign Programs to Team Members")
    V_PublishPrograms("Publish Programs (set Instant / By Request)")
    V_CreateProfilesNote["Note: Professional may create only 1 additional profile"]
  end

  %% === Entry points into booking flow & signup ===
    L --> A & PP & PR & VR & Login & Signup
    PP --> PPD
    PPD -- "CTA: Register to Book" --> Login
    PPD -- "CTA: Sign Up" --> Signup
    Login -- "Role: Parent" --> PDash
    Login -- "Role: Provider" --> VDash
    Signup --> P_SignStart & V_SignStart

  %% Parent Sign Up sequence
    P_SignStart --> P_Contact --> P_ParentProfile --> P_ChildAdd --> P_Emergency --> P_Medical --> P_Consents --> P_Terms --> P_VerifyEmail --> P_AccountChoose
    P_AccountChoose -- "Free" --> P_AccountFree
    P_AccountChoose -- "Paid / Family Plan" --> P_AccountActive
    P_VerifyEmail -- "Success" --> P_AccountActive
    P_VerifyEmail -- "Pending" --> P_AccountFree

    %% After sign up, route to dashboard
    P_AccountActive --> PDash
    P_AccountFree --> PDash

  %% Provider Sign Up sequence
    V_SignStart --> V_Contact --> V_Type
    V_Type -- "Individual" --> V_IDVerify & V_BackCheck
    V_Type -- "Business" --> V_IDVerify & V_BackCheck & V_BusinessDocs
    V_IDVerify --> V_VettingPending
    V_BackCheck --> V_VettingPending
    V_BusinessDocs --> V_VettingPending

    V_VettingPending -- "Approved" --> V_Approved
    V_VettingPending -- "Rejected" --> V_Rejected

    V_Approved --> V_CreateProfiles --> V_ProfileLimitCheck
    V_ProfileLimitCheck -- "Professional (true)" --> V_CreateProfiles & V_CreateProfilesNote
    V_ProfileLimitCheck -- "Not Professional" --> V_CreateProfiles
    V_CreateProfiles --> V_PublishPrograms
    V_PublishPrograms --> V_Prog
    V_CreateProfiles --> V_AssignPrograms

    %% Link provider to dashboards
    V_Approved --> VDash
    V_Rejected --> VDash

  %% === Booking flow entry points ===
    Booking_Start --> Auth_Check
    Auth_Check -- "No" --> Login
    Auth_Check -- "No" --> Signup
    Auth_Check -- "Yes" --> Credits_Check

    Credits_Check -- "No" --> Upgrade
    Upgrade --> Payment_Upgrade --> Registration_Form
    Credits_Check -- "Yes" --> Registration_Form

    Registration_Form --> Review_Submit
    Review_Submit --> BookingType

    BookingType -- "Yes (Instant)" --> Booking_Review --> Payment --> PostPayment
    BookingType -- "No (By request)" --> ByRequestNotify --> ParentConfirmEmail --> Booking_Pending

    Payment --> PostPayment
    PostPayment --> PDash

  %% Chat availability (can be done at any stage; active accounts only)
    Registration_Form -.->|"Can message provider (active accounts only)"| Chat_Node
    Booking_Review    -.->|"Can message provider (active accounts only)"| Chat_Node
    ByRequestNotify   -.->|"Can message provider (active accounts only)"| Chat_Node
    Payment           -.->|"Can message provider (active accounts only)"| Chat_Node
    P_Chat -->|"Access overall chat hub"| Chat_Node
    Chat_Node --> V_Chat

  %% Provider acceptance path for by-request bookings
    Booking_Pending -- "Provider accepts" --> Payment --> PostPayment
    Booking_Pending -- "Provider declines" --> PDash

  %% Provider team & profile behaviors
    V_CreateProfiles --> V_Team
    V_AssignPrograms --> V_Manage

  %% === Misc links & Navigation ===
    PDash --> P_Exp & P_Plan & P_Comm & P_Chat & P_Set
    P_Exp --> P_Book
    Login -->|"Sign Up as Parent"| Signup
    Login -->|"Sign Up as Provider"| Signup
    VDash --> V_Team & V_Prog & V_Fin & V_Chat & V_Anly
    V_Prog --> V_Manage
    P_Chat <--> V_Chat
    P_Comm -- "Post Job" --> V_Chat

    n1["Provider Profiles"]
    n1@{ shape: rounded}

  %% === Styling & classes ===
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

     %% Booking nodes
     Booking_Start:::parent
     Auth_Check:::action
     Credits_Check:::action
     Upgrade:::parent
     Payment_Upgrade:::parent
     Registration_Form:::parent
     Review_Submit:::parent
     BookingType:::action
     Booking_Review:::parent
     Payment:::parent
     PostPayment:::parent
     ByRequestNotify:::parent
     ParentConfirmEmail:::parent
     Booking_Pending:::parent
     Chat_Node:::parent

     %% Sign up nodes
     P_SignStart:::parent
     P_Contact:::parent
     P_ParentProfile:::parent
     P_ChildAdd:::parent
     P_Emergency:::parent
     P_Medical:::parent
     P_Consents:::parent
     P_Terms:::parent
     P_VerifyEmail:::action
     P_AccountChoose:::action
     P_AccountActive:::parent
     P_AccountFree:::parent

     V_SignStart:::provider
     V_Contact:::provider
     V_Type:::action
     V_IDVerify:::action
     V_BackCheck:::action
     V_Badges:::provider
     V_Experience:::provider
     V_BusinessDocs:::action
     V_VettingPending:::action
     V_Approved:::provider
     V_Rejected:::provider
     V_CreateProfiles:::provider
     V_ProfileLimitCheck:::action
     V_AssignPrograms:::provider
     V_PublishPrograms:::provider
     V_CreateProfilesNote:::provider

    classDef guest fill:#FFEAC9,stroke:#333,stroke-width:2px,color:#000
    classDef parent fill:#0FC3FF,stroke:#333,stroke-width:2px,color:#000
    classDef provider fill:#FFFF36,stroke:#333,stroke-width:2px,color:#000
    classDef action fill:#fff,stroke-dasharray: 5 5
    style Login color:#000000
    style Signup color:#000000
