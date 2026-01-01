```mermaid
flowchart TB
  %% Top-level: Guest
  subgraph Guest_Flow["Public - Guest Experience"]
    A["About Page"]
    L["Landing Page"]
    PP["Public Programs List"]
    PR["Parents Resources Blog"]
    VR["Provider Resources Blog"]
    PPD["Public Program Detail"]
    Login{"Login / Sign Up"}
    Signup["Sign Up"]
  end

  %% Parent portal
  subgraph Parent_Portal["Authenticated Parent Flow"]
    PDash["Parent Dashboard"]
    P_Exp["Explore Programs"]
    P_Plan["Planner - Calendar"]
    P_Comm["Community Feed and Jobs"]
    P_Chat["Chat and Video Calls"]
    P_Set["Account Settings"]
    P_Book["Book Activity"]
  end

  %% Provider portal
  subgraph Provider_Portal["Provider Dashboard"]
    VDash["Provider Overview"]
    V_Team["Provider Profiles"]
    V_Prog["Program Inventory"]
    V_Fin["Finance and Invoices"]
    V_Chat["Messages and Broadcasts"]
    V_Anly["Analytics and Growth"]
    V_Manage["Manage Rosters"]
    V_CreateProg["Create Program"]
    V_Publish["Publish Program"]
    V_Assign["Assign Program to Team"]
  end

  %% Booking flow
  subgraph Booking_Flow["Booking Flow"]
    Booking_Start["Start Booking"]
    Auth_Check{"Authenticated?"}
    Credits_Check{"Enough credits?"}
    Upgrade["Upgrade Account or Pay Fee"]
    Payment_Upgrade["Process Upgrade / Extra Fee"]
    Registration_Form["Registration Form (program fields)"]
    Review_Submit["Parent Review and Submit"]
    BookingType{"Instant Book?"}
    Booking_Review["Booking Review"]
    Payment["Payment"]
    PostPayment["Confirmation and Invoice"]
    ByRequestNotify["Notify Provider"]
    ParentConfirmEmail["Parent Confirmation Email"]
    Booking_Pending["Booking Pending"]
    Chat_Node["Chat Provider (active only)"]
  end

  %% Sign up flow
  subgraph SignUp_Flow["Sign Up Flow"]
    P_SignStart["Parent Sign Up Start"]
    P_Contact["Contact Details"]
    P_ParentProfile["Parent Profile"]
    P_ChildAdd["Add Child - name, DOB"]
    P_Emergency["Emergency Contact"]
    P_Medical["Medical / Allergies"]
    P_Consents["Photo / Marketing Consent"]
    P_Terms["Accept Terms and Privacy"]
    P_VerifyEmail["Email Verification"]
    P_AccountChoose{"Choose Account Type"}
    P_AccountActive["Active Account"]
    P_AccountFree["Free Account"]

    V_SignStart["Provider Sign Up Start"]
    V_Contact["Provider Contact Details"]
    V_Type{"Individual or Business?"}
    V_IDVerify["ID Verification"]
    V_BackCheck["Background Check Upload"]
    V_Badges["Add Badges / Certificates"]
    V_Experience["Select Experience Levels"]
    V_BusinessDocs["Business Registration / VAT"]
    V_VettingPending["Vetting Pending"]
    V_Approved["Provider Approved"]
    V_Rejected["Provider Rejected"]
    V_CreateProfiles["Create or Link Profile(s)"]
    V_ReviewProfile["Review and Publish Profile"]
    V_CreateBusiness["Create Business Account"]
    V_CreateProfiles_Biz["Create/Link Pro Profiles under Business"]
  end

  %% Approved branching
  V_Approved --> V_Approved_FP["Approved - Free/Professional"]
  V_Approved --> V_Approved_Biz["Approved - Business"]

  V_Approved_FP --> V_CreateProfiles
  V_CreateProfiles --> V_ReviewProfile
  V_ReviewProfile --> VDash

  V_CreateProfiles --> V_LinkOtherPro["Link one other pro account (optional)"]
  V_LinkOtherPro --> V_ReviewProfile

  V_Approved_Biz --> V_CreateBusiness
  V_CreateBusiness --> V_CreateProfiles_Biz
  V_CreateProfiles_Biz --> V_ReviewProfile
  V_CreateProfiles_Biz --> V_Assign

  %% Program creation in dashboard
  VDash --> V_CreateProg
  V_CreateProg --> V_Prog
  V_CreateProg --> V_Publish
  V_Publish --> V_Prog
  V_Publish --> V_Assign
  V_Assign --> V_Manage

  %% Navigation and sequences
  L --> A
  L --> PP
  L --> PR
  L --> VR
  L --> Login
  L --> Signup

  PP --> PPD
  PPD --> Login
  PPD --> Signup

  Login --> PDash
  Login --> VDash
  Signup --> P_SignStart
  Signup --> V_SignStart

  %% Parent sign up
  P_SignStart --> P_Contact --> P_ParentProfile --> P_ChildAdd --> P_Emergency --> P_Medical --> P_Consents --> P_Terms --> P_VerifyEmail --> P_AccountChoose
  P_AccountChoose --> P_AccountFree
  P_AccountChoose --> P_AccountActive
  P_AccountActive --> PDash
  P_AccountFree --> PDash

  %% Provider signup & vetting
  V_SignStart --> V_Contact --> V_Type
  V_Type --> V_IDVerify
  V_Type --> V_BackCheck
  V_Type --> V_BusinessDocs
  V_IDVerify --> V_VettingPending
  V_BackCheck --> V_VettingPending
  V_BusinessDocs --> V_VettingPending
  V_VettingPending --> V_Approved
  V_VettingPending --> V_Rejected
  V_Rejected --> VDash
  V_Approved --> V_CreateProfiles

  %% Booking checks
  Booking_Start --> Auth_Check
  Auth_Check --> Login
  Auth_Check --> Signup
  Auth_Check --> Credits_Check

  Credits_Check --> Upgrade
  Upgrade --> Payment_Upgrade --> Registration_Form
  Credits_Check --> Registration_Form

  Registration_Form --> Review_Submit --> BookingType
  BookingType --> Booking_Review --> Payment --> PostPayment
  BookingType --> ByRequestNotify --> ParentConfirmEmail --> Booking_Pending
  PostPayment --> PDash

  %% Chat (simplified)
  Registration_Form -.-> Chat_Node
  Booking_Review -.-> Chat_Node
  ByRequestNotify -.-> Chat_Node
  Payment -.-> Chat_Node
  P_Chat --> Chat_Node
  Chat_Node --> V_Chat

  %% Provider acceptance
  Booking_Pending --> Payment
  Booking_Pending --> PDash

  %% Dash navigation
  PDash --> P_Exp
  PDash --> P_Plan
  PDash --> P_Comm
  PDash --> P_Chat
  PDash --> P_Set
  P_Exp --> P_Book

  VDash --> V_Team
  VDash --> V_Prog
  VDash --> V_Fin
  VDash --> V_Chat
  VDash --> V_Anly
  V_Prog --> V_Manage
  V_Prog --> V_CreateProg

  P_Chat <--> V_Chat
  P_Comm --> V_Chat

  n1["Provider Profiles"]
