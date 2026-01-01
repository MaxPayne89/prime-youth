flowchart TB
  %% Top-level: Guest
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

  %% Parent portal
  subgraph Parent_Portal["Authenticated Parent Flow"]
    PDash["Parent Dashboard"]
    P_Exp["Explore Programs"]
    P_Plan["Planner / Calendar (paid)"]
    P_Comm["Community Feed and Jobs"]
    P_Chat["Chat and Video Calls"]
    P_Set["Account Settings"]
    P_Book["Book Activity"]
  end

  %% Provider portal (dashboard & program management)
  subgraph Provider_Portal["Authenticated Provider Flow"]
    VDash["Provider Overview"]
    V_Team["Provider Profiles"]
    V_Prog["Program Inventory"]
    V_Fin["Finance: Expenses and Invoices"]
    V_Chat["Messages and Broadcasts"]
    V_Anly["Analytics and Growth"]
    V_Manage["Manage Rosters"]
    V_CreateProg["Create Program"]
    V_PublishPrograms["Publish Program"]
    V_AssignPrograms["Assign Program to Profiles / Team"]
  end

  %% Booking flow
  subgraph Booking_Flow["Booking Flow (Parent)"]
    Booking_Start["Start Booking (from Landing, Programs, or Parent Book CTA)"]
    Auth_Check{"Authenticated?"}
    Credits_Check{"Enough credits?"}
    Upgrade["Upgrade Account or Pay Extra Fee"]
    Payment_Upgrade["Payment: Upgrade / Extra Fee"]
    Registration_Form["Registration Form (fields required by program)"]
    Review_Submit["Parent Review and Submit"]
    BookingType{"Program is Instant Book?"}
    Booking_Review["Booking Review and Confirmation"]
    Payment["Payment"]
    PostPayment["Registration Confirmation and Invoice (sent to Provider and Parent)"]
    ByRequestNotify["Send notification email to Provider"]
    ParentConfirmEmail["Confirmation email to Parent (request received)"]
    Booking_Pending["Booking Pending / Awaiting Provider Approval"]
    Chat_Node["Chat Provider (active accounts only)"]
  end

  %% Sign up flow (Parents and Providers)
  subgraph SignUp_Flow["Sign Up Flow"]
    %% Parent sign up
    P_SignStart["Parent Sign Up Start"]
    P_Contact["Contact Details (email, phone, address)"]
    P_ParentProfile["Parent Profile (name, preferred contact)"]
    P_ChildAdd["Add Child(ren): name and DOB"]
    P_Emergency["Emergency Contact"]
    P_Medical["Medical Info / Allergies / Needs"]
    P_Consents["Photo/Media Consent and Marketing opt-in"]
    P_Terms["Accept Terms and Conditions and Privacy Policy"]
    P_VerifyEmail["Email Verification"]
    P_AccountChoose{"Choose Account Type (Free / Paid / Business Family Plan)"}
    P_AccountActive["Account Active (full features)"]
    P_AccountFree["Free Account (limited: no chat, limited credits)"]

    %% Provider sign up and vetting
    V_SignStart["Provider Sign Up Start"]
    V_Contact["Provider Contact Details"]
    V_Type{"Sign up as Individual or Business?"}
    V_IDVerify["ID Verification (gov ID upload)"]
    V_BackCheck["Police / Background Check Upload"]
    V_Badges["Optional: Add Badges and Certificates (First Aid, Safeguarding, Degrees)"]
    V_Experience["Select Experience Levels by Category: Art / Sports / Life Skills / Academic (new / 5yrs / 10yrs / >20yrs)"]
    V_BusinessDocs["Business Registration and VAT (if Business Plan)"]
    V_VettingPending["Vetting Pending (docs review)"]
    V_Approved["Provider Approved (vetting passed)"]
    V_Rejected["Provider Rejected (feedback sent)"]
    V_CreateProfiles["Create or Link Profile(s) (personal or pro profile)"]
    V_ReviewProfile["Review and Publish Profile"]
    V_CreateBusiness["Create Business Account (business plan)"]
    V_CreateProfiles_Biz["Create or Link Pro Profiles under Business"]
  end

  %% Approved-provider branching (separate edges for GitHub compatibility)
  V_Approved --> V_Approved_FP
  V_Approved --> V_Approved_Biz

  V_Approved_FP["Approved - Free or Professional flow"]
  V_Approved_Biz["Approved - Business flow"]

  %% Free / Professional flow
  V_Approved_FP --> V_CreateProfiles
  V_CreateProfiles --> V_ReviewProfile
  V_ReviewProfile --> VDash

  %% If professional, optionally link one other pro account
  V_CreateProfiles --> V_LinkOtherPro
  V_LinkOtherPro["Link one other pro account (optional)"]
  V_LinkOtherPro --> V_ReviewProfile

  %% Business flow
  V_Approved_Biz --> V_CreateBusiness
  V_CreateBusiness --> V_CreateProfiles_Biz
  V_CreateProfiles_Biz --> V_ReviewProfile
  V_CreateProfiles_Biz --> V_AssignPrograms
  V_CreateBusiness --> V_BusinessDocs

  %% Program creation lives in provider dashboard
  VDash --> V_CreateProg
  V_CreateProg --> V_Prog
  V_CreateProg --> V_PublishPrograms
  V_PublishPrograms --> V_Prog
  V_PublishPrograms --> V_AssignPrograms
  V_AssignPrograms --> V_Manage

  %% Entry points, navigation and sequences
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

  %% Parent signup sequence
  P_SignStart --> P_Contact
  P_Contact --> P_ParentProfile
  P_ParentProfile --> P_ChildAdd
  P_ChildAdd --> P_Emergency
  P_Emergency --> P_Medical
  P_Medical --> P_Consents
  P_Consents --> P_Terms
  P_Terms --> P_VerifyEmail
  P_VerifyEmail --> P_AccountChoose
  P_AccountChoose --> P_AccountFree
  P_AccountChoose --> P_AccountActive
  P_AccountActive --> PDash
  P_AccountFree --> PDash

  %% Provider signup sequence
  V_SignStart --> V_Contact
  V_Contact --> V_Type
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

  %% Booking flow entry and checks
  Booking_Start --> Auth_Check
  Auth_Check --> Login
  Auth_Check --> Signup
  Auth_Check --> Credits_Check

  Credits_Check --> Upgrade
  Upgrade --> Payment_Upgrade
  Payment_Upgrade --> Registration_Form
  Credits_Check --> Registration_Form

  Registration_Form --> Review_Submit
  Review_Submit --> BookingType
  BookingType --> Booking_Review
  Booking_Review --> Payment
  BookingType --> ByRequestNotify
  ByRequestNotify --> ParentConfirmEmail
  ParentConfirmEmail --> Booking_Pending
  Payment --> PostPayment
  PostPayment --> PDash

  %% Chat availability (no labels to maximize GitHub compatibility)
  Registration_Form -.-> Chat_Node
  Booking_Review -.-> Chat_Node
  ByRequestNotify -.-> Chat_Node
  Payment -.-> Chat_Node
  P_Chat --> Chat_Node
  Chat_Node --> V_Chat

  %% Provider acceptance for by-request bookings
  Booking_Pending --> Payment
  Booking_Pending --> PDash

  %% Provider dashboard navigation
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

  V_Badges <--> V_Experience
  V_Experience <--> V_CreateProfiles
  V_CreateProfiles_Biz <--> V_Team

  n1["Provider Profiles"]
  n1@{ shape: rounded }

  %% Styling (GitHub mermaid supports classDef and class)
  classDef guest fill:#FFEAC9,stroke:#333,stroke-width:2px,color:#000
  classDef parent fill:#0FC3FF,stroke:#333,stroke-width:2px,color:#000
  classDef provider fill:#FFFF36,stroke:#333,stroke-width:2px,color:#000
  classDef action fill:#fff,stroke-dasharray: 5 5

  class A,L,PP,PR,VR,PPD guest
  class Login,Signup action
  class PDash,P_Exp,P_Plan,P_Comm,P_Chat,P_Set,P_Book parent
  class VDash,V_Team,V_Prog,V_Fin,V_Chat,V_Anly,V_Manage,V_CreateProg provider
