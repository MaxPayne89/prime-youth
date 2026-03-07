# Changelog

All notable changes to the Klass Hero project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4](https://github.com/MaxPayne89/prime-youth/compare/v0.1.3...v0.1.4) (2026-03-07)


### Features

* **family:** handle cross-context cleanup in DeleteChild ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([6582629](https://github.com/MaxPayne89/prime-youth/commit/65826293a784b7dd723788a530a27c43ab2ba687))
* **liveview:** two-step child deletion with enrollment warning ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([567e3a0](https://github.com/MaxPayne89/prime-youth/commit/567e3a04bfd22d867a3826173d1c592c5671d253))


### Bug Fixes

* add error handling and observability for child deletion ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([af78e18](https://github.com/MaxPayne89/prime-youth/commit/af78e18ec9586441087b9b280d7dd7ce1669a791))
* address architecture review findings for child deletion ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([4b4f860](https://github.com/MaxPayne89/prime-youth/commit/4b4f8601f32fd87b073087d46c4199e535d177e5))
* address critical architecture review findings ([#299](https://github.com/MaxPayne89/prime-youth/issues/299)) ([780bc54](https://github.com/MaxPayne89/prime-youth/commit/780bc549ce3426e6c8335c7aa99413b188ca9a65))
* address important review findings for invite claim processing ([#299](https://github.com/MaxPayne89/prime-youth/issues/299)) ([f2e41a2](https://github.com/MaxPayne89/prime-youth/commit/f2e41a276a670903c01c252fab4a79e1258157ea))
* address PR [#304](https://github.com/MaxPayne89/prime-youth/issues/304) review comments for child deletion ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([de6e214](https://github.com/MaxPayne89/prime-youth/commit/de6e214c02a4840361c394fed600ad3da0f6ef1a))
* address PR review comments for invite claim processing ([#299](https://github.com/MaxPayne89/prime-youth/issues/299)) ([73e5161](https://github.com/MaxPayne89/prime-youth/commit/73e51615cd2e3a865887b58945f1e4af11f3259f))
* address PR review suggestions for child deletion ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([e51960f](https://github.com/MaxPayne89/prime-youth/commit/e51960f03e5088f578f95a6a306c199fb60bdc0c))
* address suggestion-level review findings ([#299](https://github.com/MaxPayne89/prime-youth/issues/299)) ([0a7636f](https://github.com/MaxPayne89/prime-youth/commit/0a7636f9b15aeb36f9865aad8071419047752926))
* cast binary UUIDs to string in remediation script output ([5ae1b76](https://github.com/MaxPayne89/prime-youth/commit/5ae1b76cd8773468db8203786603c7e6a546cb42))
* cast binary UUIDs to string in remediation script output ([3aeb7d7](https://github.com/MaxPayne89/prime-youth/commit/3aeb7d7eef08ccdaa479c42690957277bc757132))
* guard against nil delete_candidate in confirm handler ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([077fc96](https://github.com/MaxPayne89/prime-youth/commit/077fc96373c1570d9bd42f9eed76c9255ee36b4c))
* prevent duplicate child records on invite claim ([#299](https://github.com/MaxPayne89/prime-youth/issues/299)) ([ed9086b](https://github.com/MaxPayne89/prime-youth/commit/ed9086bcd20288d0b5c5e56424851adbb2da2d63))
* two-step child deletion with enrollment cleanup ([#298](https://github.com/MaxPayne89/prime-youth/issues/298)) ([7359d97](https://github.com/MaxPayne89/prime-youth/commit/7359d97059b89dfb1b0bc2ad499aaeb427cdd8ae))


### Code Refactoring

* cleanup post-review for invite claim processing ([#299](https://github.com/MaxPayne89/prime-youth/issues/299)) ([5b9404e](https://github.com/MaxPayne89/prime-youth/commit/5b9404eaf07eef36b5a67fd0e867daf52951f868))

## [0.1.3](https://github.com/MaxPayne89/prime-youth/compare/v0.1.2...v0.1.3) (2026-03-06)


### Features

* add skeleton Trust & Safety page with route and test ([#250](https://github.com/MaxPayne89/prime-youth/issues/250)) ([74cc92e](https://github.com/MaxPayne89/prime-youth/commit/74cc92e284090472164a6ee80454fd552998c4f8))
* add Trust & Safety links to navbar, sidebar, and footer ([#250](https://github.com/MaxPayne89/prime-youth/issues/250)) ([cd5fea5](https://github.com/MaxPayne89/prime-youth/commit/cd5fea534bd2c21f14249a9e3c5523725e7e8272))
* add Trust & Safety page ([#250](https://github.com/MaxPayne89/prime-youth/issues/250)) ([453b726](https://github.com/MaxPayne89/prime-youth/commit/453b7260949e8cd077606abd7bcfadbe8fa35bc3))
* implement full Trust & Safety page content ([#250](https://github.com/MaxPayne89/prime-youth/issues/250)) ([ccc40a5](https://github.com/MaxPayne89/prime-youth/commit/ccc40a57eeb044c02d2e970d9d57b8f0be43eb91))
* update provider vetting to 6-step process across all pages ([98d7879](https://github.com/MaxPayne89/prime-youth/commit/98d78794ad278ddad36ae6d4563775abd47279ca))
* update provider vetting to 6-step process across all pages ([#251](https://github.com/MaxPayne89/prime-youth/issues/251)) ([dfd757e](https://github.com/MaxPayne89/prime-youth/commit/dfd757e87ec9e6f95bd097270009dc1fa80ee0d0))


### Bug Fixes

* address PR review comments for vetting steps ([#251](https://github.com/MaxPayne89/prime-youth/issues/251)) ([10644e8](https://github.com/MaxPayne89/prime-youth/commit/10644e83c768c9fdc4f950cd637ebe75ae5d7be6))
* use consistent Unicode bullet in footer separator ([#250](https://github.com/MaxPayne89/prime-youth/issues/250)) ([e5c3f7c](https://github.com/MaxPayne89/prime-youth/commit/e5c3f7c4f3253976b6722cb7185e4da5e655836f))


### Code Refactoring

* extract repeated icon gradient to module attribute ([#250](https://github.com/MaxPayne89/prime-youth/issues/250)) ([382a2fc](https://github.com/MaxPayne89/prime-youth/commit/382a2fce6460dfa24dc77b929c511b699268721e))

## [0.1.2](https://github.com/MaxPayne89/prime-youth/compare/v0.1.1...v0.1.2) (2026-03-06)


### Bug Fixes

* handle HH:MM:SS time format in program save ([b4d17dc](https://github.com/MaxPayne89/prime-youth/commit/b4d17dc1a0f2f6129d2e58bbd9f5bbf41fe24932))
* handle HH:MM:SS time format in program save ([#282](https://github.com/MaxPayne89/prime-youth/issues/282)) ([3e85491](https://github.com/MaxPayne89/prime-youth/commit/3e854912d62f645a9fe8bc5ce6054b4ac90d03bd))
* normalize qualifications params in save error paths ([e2c2b1f](https://github.com/MaxPayne89/prime-youth/commit/e2c2b1f29bf65ccb6fe9441838958e10f3b817f0))
* normalize qualifications params in save error paths ([57fc0c5](https://github.com/MaxPayne89/prime-youth/commit/57fc0c5cd3782ae73a49072ec3d594bb109b2c28)), closes [#141](https://github.com/MaxPayne89/prime-youth/issues/141)

## [0.1.1](https://github.com/MaxPayne89/prime-youth/compare/v0.1.0...v0.1.1) (2026-03-05)


### Features

* **accounts:** add generate_magic_link_token for invite flow ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([0284584](https://github.com/MaxPayne89/prime-youth/commit/028458417dbde95337c07292d9387ca0d208aebe))
* add ACL adapters bridging Family and ProgramCatalog into Enrollment ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([d33c493](https://github.com/MaxPayne89/prime-youth/commit/d33c493bc9b0c49e450768378251230a860aaf1b))
* add bulk_assign_tokens/1 to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([1a5c3f0](https://github.com/MaxPayne89/prime-youth/commit/1a5c3f0d01a601ab09f9f873c3c1365b3cc1f097))
* add bulk_invites_imported event factory ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([5f7d84a](https://github.com/MaxPayne89/prime-youth/commit/5f7d84a35a49149f1198d66679f3537f38359196))
* add BulkEnrollmentInvite domain model ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([4ea1393](https://github.com/MaxPayne89/prime-youth/commit/4ea13937687bbc0a71d6d649f4838ee6d1dfa4a8))
* add BulkEnrollmentInvite mapper ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([22c6815](https://github.com/MaxPayne89/prime-youth/commit/22c681563afb4fbebdc9f5d3b097d5309819a55b))
* add centralized contact info config and helper ([d235dd8](https://github.com/MaxPayne89/prime-youth/commit/d235dd832010c4405220802527686f2cdeaac82d))
* add change_subscription_tier/2 to Provider facade ([00dce82](https://github.com/MaxPayne89/prime-youth/commit/00dce8239d60e8a2fd267dc78b7461761eedbba3))
* add change_tier/2 to ProviderProfile domain model ([afb555c](https://github.com/MaxPayne89/prime-youth/commit/afb555c52ffbc99a58a93e1e98cb42dab9f28071))
* add ChangeSubscriptionTier use case ([302366b](https://github.com/MaxPayne89/prime-youth/commit/302366b7f8a3065d8d880afa0b24ef36e7fa905d))
* add CheckParticipantEligibility use case ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([a4b9711](https://github.com/MaxPayne89/prime-youth/commit/a4b9711db5209ffc8a31fa65e8f237bf0085d416))
* add CheckProviderVerificationStatus domain event handler ([fbd5d5e](https://github.com/MaxPayne89/prime-youth/commit/fbd5d5ed819bfa540ee06369536852f289bde650))
* add ChildInfoACL adapter with DI config ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([00ff136](https://github.com/MaxPayne89/prime-youth/commit/00ff136a75d5261662bf0dc321f2b97c52d4a208))
* add CQRS denormalized read models for ProgramCatalog and Messaging ([291e396](https://github.com/MaxPayne89/prime-youth/commit/291e396636f1b59ab7908a6232689008797a1306))
* add Edit, View Roster, and Preview actions to provider dashboard ([8ae65da](https://github.com/MaxPayne89/prime-youth/commit/8ae65dab0d914b9226bc9ddbfbfd4ddcba5dfb68))
* add enrollment capacity fields to provider program form ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([6835add](https://github.com/MaxPayne89/prime-youth/commit/6835addb2afc734d74245d603b82f1c990eeb2d1))
* add enrollment capacity management ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([299a66e](https://github.com/MaxPayne89/prime-youth/commit/299a66e6fd8ed90896afe5168305dffdcb575e73))
* add EnrollmentCapacityACL for program catalog capacity display ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([71a82b7](https://github.com/MaxPayne89/prime-youth/commit/71a82b73ebbd99c6d304143a8cce433c81a435a0))
* add EnrollmentPolicy domain model ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([867cded](https://github.com/MaxPayne89/prime-youth/commit/867cded265c6424789aee8e2ebc0ce49a1dafc78))
* add EnrollmentPolicy persistence layer ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([c025630](https://github.com/MaxPayne89/prime-youth/commit/c0256308196e1dffadc556a6eacac65357d8df37))
* add event handler to enqueue invite emails after import ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e3eb650](https://github.com/MaxPayne89/prime-youth/commit/e3eb650661a192d1415ca898a381391df35af3e9))
* add event publishing to Enrollment context for participant policies ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([c2cbd53](https://github.com/MaxPayne89/prime-youth/commit/c2cbd53f7756de17710c9c6d68291e76af1e7665))
* add Family Programs section to parent dashboard ([f5db2f4](https://github.com/MaxPayne89/prime-youth/commit/f5db2f4d7af3fda44833dcc2e0c437a2add1cd98))
* add Family Programs section to parent dashboard ([#154](https://github.com/MaxPayne89/prime-youth/issues/154)) ([1d408e8](https://github.com/MaxPayne89/prime-youth/commit/1d408e88aeb37caab2cce13d3a836fb61d693a1a))
* add ForManagingEnrollmentPolicies port ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([9007dfd](https://github.com/MaxPayne89/prime-youth/commit/9007dfd49e7af7e0f39beaa4229381bb595cf7e1))
* add ForResolvingChildInfo ACL port + list_by_program repo method ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([b21bfdd](https://github.com/MaxPayne89/prime-youth/commit/b21bfdd554986447c7458f35ae0a2641eb81db32))
* add founder section to homepage ([#179](https://github.com/MaxPayne89/prime-youth/issues/179)) ([d94d2b2](https://github.com/MaxPayne89/prime-youth/commit/d94d2b2c1bf4cfe4be845664bcddf4de4929e793))
* add founding story to About page ([#180](https://github.com/MaxPayne89/prime-youth/issues/180)) ([3066b29](https://github.com/MaxPayne89/prime-youth/commit/3066b2976182e9542eff10d1cc09284b8c4e5436))
* add gender and school grade fields to children settings ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([0e20f9b](https://github.com/MaxPayne89/prime-youth/commit/0e20f9bf32324bb21220336ce05a68a945630b2c))
* add gender and school_grade fields to Child ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([ffe2eed](https://github.com/MaxPayne89/prime-youth/commit/ffe2eedfb59679fb7ece0eee7e304db4e651ea0f))
* add get_by_id/1 to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([1d2a2fd](https://github.com/MaxPayne89/prime-youth/commit/1d2a2fdc0e871a3db2049f54235cc74387889d29))
* add icon_name/1 mapping categories to heroicons ([a79302d](https://github.com/MaxPayne89/prime-youth/commit/a79302d1a72f63fcc4d27e0b040d2d4415232e54))
* add invite email port and notifier adapter ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([b0ecacb](https://github.com/MaxPayne89/prime-youth/commit/b0ecacb9ed749f712b9b15b07e69e3f633841b8e))
* add list_pending_without_token/1 to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([f57e01e](https://github.com/MaxPayne89/prime-youth/commit/f57e01e4e33b214324bca899af6ee2637052ebbb))
* add ListProgramEnrollments use case with TDD tests ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([b2730a0](https://github.com/MaxPayne89/prime-youth/commit/b2730a00f6d8f72414a69bac2c844cae458bf5c8))
* add Oban worker for sending invite emails ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([59d14fc](https://github.com/MaxPayne89/prime-youth/commit/59d14fc30292c9406920115b7cdd64376e95e5e9))
* add participant restrictions form to provider dashboard ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([49506bb](https://github.com/MaxPayne89/prime-youth/commit/49506bb17ce19445ad2607ffc6e873de37eb5b5d))
* add ParticipantPolicy domain model with eligibility logic ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([0cab7af](https://github.com/MaxPayne89/prime-youth/commit/0cab7af1543b5591c5f74ba48b7a11ef6ccf443e))
* add ParticipantPolicy persistence layer ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([877374f](https://github.com/MaxPayne89/prime-youth/commit/877374f93300840c98b7f9de5b611b56c5d45057))
* add program_schedule_updated event and update event payloads ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([7dec257](https://github.com/MaxPayne89/prime-youth/commit/7dec257db596decd7e429203158d87a852e1d42e))
* add Program.create/1 factory and apply_changes/2 with business invariant validation ([b755857](https://github.com/MaxPayne89/prime-youth/commit/b755857c23bcdbf4d24e2323b41cb31255c2f2a9))
* add provider subscription management page ([58e07fc](https://github.com/MaxPayne89/prime-youth/commit/58e07fc17f5bf43f6d76aa97417e3dfe890d0d58))
* add registration period fields to programs schema ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([220ef8c](https://github.com/MaxPayne89/prime-youth/commit/220ef8ca72787d08af72b048b09e4f7d47bc7a3d))
* add registration period for programs ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([2982769](https://github.com/MaxPayne89/prime-youth/commit/298276977def074945f30091a548e4fe44f05354))
* add registration period inputs to provider program form ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([4b0c3d0](https://github.com/MaxPayne89/prime-youth/commit/4b0c3d017f529d893c880fdab192bbd02f69b32a))
* add registration_period to Program domain model ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([515e923](https://github.com/MaxPayne89/prime-youth/commit/515e9235bc1d7544d7be0376aade8abe67488a40))
* add RegistrationPeriod value object ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([61a9e2d](https://github.com/MaxPayne89/prime-youth/commit/61a9e2d5fde3f1ded1ba51e58dcb44acc713c03d))
* add schedule formatting to ProgramPresenter ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([7ed4967](https://github.com/MaxPayne89/prime-youth/commit/7ed49679f3d92380671fb74c135032ff29b4e268))
* add scheduling fields migration ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([6538603](https://github.com/MaxPayne89/prime-youth/commit/6538603a77960508e7677a2dd6afd378fbff2ba7))
* add scheduling fields to Program domain model ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([eb5a006](https://github.com/MaxPayne89/prime-youth/commit/eb5a0063bd22844196afc76aad61f256f5f50bde))
* add scheduling fields to ProgramSchema ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([eadaff9](https://github.com/MaxPayne89/prime-youth/commit/eadaff92c8018fc5bef12ec40b53bbffe0ca0764))
* add scheduling fields to provider program form ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([7a3e1b4](https://github.com/MaxPayne89/prime-youth/commit/7a3e1b4cd19dcaeb67e4fa6b2780ca2b458faa56))
* add structured scheduling fields to programs ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([3f11f5c](https://github.com/MaxPayne89/prime-youth/commit/3f11f5c9e3ea63c09d419cb5d81c4373af967268))
* add subscription CTA banner to provider dashboard ([562e038](https://github.com/MaxPayne89/prime-youth/commit/562e038891e8212c05ef5fc681b162e7b0958789))
* add subscription upgrade path for providers ([cf7ed19](https://github.com/MaxPayne89/prime-youth/commit/cf7ed198aae24faf1ab18820ce5b97bbd5dc0096))
* add tier selector to provider registration flow ([5fa952d](https://github.com/MaxPayne89/prime-youth/commit/5fa952db590b648d2ccc8325c29c970524d641bc))
* add to_card_view/1 to ProgramPresenter ([#154](https://github.com/MaxPayne89/prime-youth/issues/154)) ([cb9456b](https://github.com/MaxPayne89/prime-youth/commit/cb9456bd2b2507c8b515a866d2a5050466e5cbd3))
* add transition_status/2 to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([5d67a2f](https://github.com/MaxPayne89/prime-youth/commit/5d67a2f5f1559cbbbc316f9b04c8ad37f6257850))
* add UpdateProgram use case, update dashboard for aggregate pattern, fix test breakage ([3f338e0](https://github.com/MaxPayne89/prime-youth/commit/3f338e09e31c1d0160382b7c7b48a64168e8a470))
* add View Roster modal with enrollment display ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([65ebe1e](https://github.com/MaxPayne89/prime-youth/commit/65ebe1eb974a0c242a7e4238a31ae531364d3683))
* **app:** wire invite claim saga handlers in supervision tree ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([4264846](https://github.com/MaxPayne89/prime-youth/commit/42648460ffb43a9acc079dee95b359021792a244))
* BookingLive uses enrollment capacity instead of spots_available ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([9746215](https://github.com/MaxPayne89/prime-youth/commit/97462151dc4725ac0e86c41cc9d716afa10883dc))
* bulk enrollment invite email pipeline ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([52956a4](https://github.com/MaxPayne89/prime-youth/commit/52956a4ba33ac96c0149059d27a77c4fb37d5303))
* dispatch domain event on document approval ([061f539](https://github.com/MaxPayne89/prime-youth/commit/061f539e545b8fa2cfbbfd8f8321fdf6d2e6be35))
* dispatch domain event on document rejection ([950ba80](https://github.com/MaxPayne89/prime-youth/commit/950ba80227c4ddefdc467cdf13a1b368d7551146))
* display participant restrictions on program detail page ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([e6f37a7](https://github.com/MaxPayne89/prime-youth/commit/e6f37a7b9e512743b045774f50f69085c5260e32))
* enforce max capacity in CreateEnrollment use case ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([0fdd50b](https://github.com/MaxPayne89/prime-youth/commit/0fdd50b04026318692fe1d6f82da4eb00cb85382))
* enforce participant eligibility in CreateEnrollment ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([d2a0eee](https://github.com/MaxPayne89/prime-youth/commit/d2a0eeed2adb5020a2fa36f8c98c59e73b385499))
* **enrollment:** add BulkEnrollmentInvite schema ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([743fd73](https://github.com/MaxPayne89/prime-youth/commit/743fd73a9d149b18d7c181bb0d9a2b61f3da2018))
* **enrollment:** add BulkEnrollmentInviteRepository adapter ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([9ae88bc](https://github.com/MaxPayne89/prime-youth/commit/9ae88bc94d4460276405a6b49866e70bc3d26652))
* **enrollment:** add claim_invite to public API ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e344f00](https://github.com/MaxPayne89/prime-youth/commit/e344f00791e682080402b3fc1030039996e2d4a5))
* **enrollment:** add ClaimInvite use case ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([bdf1777](https://github.com/MaxPayne89/prime-youth/commit/bdf1777db33021acdf0133defa3c4f0cab15bc5a))
* **enrollment:** add count_by_program and delete to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([601b849](https://github.com/MaxPayne89/prime-youth/commit/601b8494560618d92a9065ef4b78519c4f1f37cb))
* **enrollment:** add CSV import controller endpoint ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e583d46](https://github.com/MaxPayne89/prime-youth/commit/e583d46b53caaa119fda7831b9d9d364ef86299e))
* **enrollment:** add CSV import template for download ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([8cf23e9](https://github.com/MaxPayne89/prime-youth/commit/8cf23e95ba28162fcf58f5262a4af2e00a7fb274))
* **enrollment:** add CsvParser domain service ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([fc20cb4](https://github.com/MaxPayne89/prime-youth/commit/fc20cb49a7e5c65af30d9b5b886a95165d98bd5b))
* **enrollment:** add DeleteInvite use case ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([466359e](https://github.com/MaxPayne89/prime-youth/commit/466359ed79dd17a5d1abda3fee3368313aede685))
* **enrollment:** add get_by_token to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([a5553d6](https://github.com/MaxPayne89/prime-youth/commit/a5553d60e886d8d5e1f56c527ea0a216284cb0f5))
* **enrollment:** add import_changeset and transition_changeset with state machine ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([f83a5eb](https://github.com/MaxPayne89/prime-youth/commit/f83a5eb34052dab6af84e3383da6c167d0fd5b3f))
* **enrollment:** add ImportEnrollmentCsv use case ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([d65395c](https://github.com/MaxPayne89/prime-youth/commit/d65395c33ffc08bf2a6009fb81d2b18fd5f0b3fe))
* **enrollment:** add ImportRowValidator domain service ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([2c58d00](https://github.com/MaxPayne89/prime-youth/commit/2c58d0060f17336221851b286d5135c5742dff10))
* **enrollment:** add invite_claimed domain + integration events ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([d6435ff](https://github.com/MaxPayne89/prime-youth/commit/d6435ff4f1bff68322a5e5861a951ad48e55be0c))
* **enrollment:** add InviteFamilyReadyHandler for enrollment creation ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([c5d814b](https://github.com/MaxPayne89/prime-youth/commit/c5d814b92e7d636fb970e2fa4f6eaf8812459807))
* **enrollment:** add list_by_program to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([9076882](https://github.com/MaxPayne89/prime-youth/commit/9076882bfccf5c5b9fe16d652a80b43b455e5ced))
* **enrollment:** add ListProgramInvites use case ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e2e8305](https://github.com/MaxPayne89/prime-youth/commit/e2e8305c602304b6b29a899827ebed576aecbae0))
* **enrollment:** add MarkInviteRegistered domain event handler ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([c7efbdb](https://github.com/MaxPayne89/prime-youth/commit/c7efbdb6495499902b4f4a19c80dd2a5ee8a79f2))
* **enrollment:** add password note to invite email template ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([bdab6a3](https://github.com/MaxPayne89/prime-youth/commit/bdab6a3d74b44db22f465a503ab34d553529204d))
* **enrollment:** add ports for bulk invite storage and program catalog lookup ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([816fcc0](https://github.com/MaxPayne89/prime-youth/commit/816fcc0de82b74a3d6179245c1bbcff76cee28bc))
* **enrollment:** add ProgramCatalogACL for cross-context program lookup ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([1e48232](https://github.com/MaxPayne89/prime-youth/commit/1e482323c698eb347de82289531a7acddf1bef29))
* **enrollment:** add ResendInvite use case ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([550437a](https://github.com/MaxPayne89/prime-youth/commit/550437a5dda8d0292f509a63476d62f1970d44df))
* **enrollment:** add reset_for_resend to invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([98da02d](https://github.com/MaxPayne89/prime-youth/commit/98da02d7f0982926849c801d0485a52dd1348a45))
* **enrollment:** bulk enrollment invite management UI ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([6e00600](https://github.com/MaxPayne89/prime-youth/commit/6e00600d5d250b8fc0c499d47ee086bb0905926a))
* **enrollment:** CSV bulk import backend ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([dc868d8](https://github.com/MaxPayne89/prime-youth/commit/dc868d8b32c943c6eb9dba2614a64dba257c806c))
* **enrollment:** expose import_enrollment_csv on context facade ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([d5419d3](https://github.com/MaxPayne89/prime-youth/commit/d5419d3a7fabc3ebbf42b8d3cd50e6997bbb8997))
* **enrollment:** expose invite management functions on facade ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e8a2a63](https://github.com/MaxPayne89/prime-youth/commit/e8a2a63164f74bcb79c4e16d88d768ef0bdb8c70))
* **enrollment:** promote invite_claimed to integration event ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([39a0906](https://github.com/MaxPayne89/prime-youth/commit/39a090605da2be1261e6d2cf8e7cc91107e08796))
* extend program_card with expired/contact attrs and date range display ([b12ccb7](https://github.com/MaxPayne89/prime-youth/commit/b12ccb7f7c45e3a1d872c75b727fe7058c20d29c)), closes [#154](https://github.com/MaxPayne89/prime-youth/issues/154)
* **family:** add children_guardians join table ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([7b5732d](https://github.com/MaxPayne89/prime-youth/commit/7b5732d1b510cf9df2a65c016dadb3448998cfca))
* **family:** add invite_family_ready domain + integration events ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([ef3a7d6](https://github.com/MaxPayne89/prime-youth/commit/ef3a7d6d6f2ef2c1bb47563df01035a701d3bf74))
* **family:** add InviteClaimedHandler for child creation from invite ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e0f2846](https://github.com/MaxPayne89/prime-youth/commit/e0f28461ce4f63958d9bd7fbc7b039a7721f9512))
* **family:** add primary guardian uniqueness and relationship constraints ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([3eb2365](https://github.com/MaxPayne89/prime-youth/commit/3eb2365b7ef7fc0c713e4bd67cda2db5189281a7))
* **family:** add school_name field to Child ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([db772ae](https://github.com/MaxPayne89/prime-youth/commit/db772aebd232c63b0e78ecd49f99c5784ba5b1fd))
* **family:** promote invite_family_ready to integration event ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([9d46f52](https://github.com/MaxPayne89/prime-youth/commit/9d46f52b30b8cdef116f4eea9e336a9bd7f21ddb))
* **family:** split photo consent into photo_marketing and photo_social_media ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([9ae608e](https://github.com/MaxPayne89/prime-youth/commit/9ae608e46ab9721a57c330def9a32ff8fcf7fa9f))
* gate booking flow on registration period ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([cfec8e8](https://github.com/MaxPayne89/prime-youth/commit/cfec8e8cec50d1ed87fe8833c1d82335f9947998))
* invite claim & auto-registration saga ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([9bd1f2f](https://github.com/MaxPayne89/prime-youth/commit/9bd1f2f85cb257dce2b0f1305c7b47a04010878d))
* map registration period between domain and schema ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([b4d2571](https://github.com/MaxPayne89/prime-youth/commit/b4d2571c088a6941c1f0441694bdfb0002bb2dda))
* **messaging:** add conversation_summaries read model table ([2f6f9ee](https://github.com/MaxPayne89/prime-youth/commit/2f6f9ee8bb036ba9cf8ea886062ce69bbfcd2f21))
* **messaging:** add ConversationSummariesProjection GenServer ([876a99b](https://github.com/MaxPayne89/prime-youth/commit/876a99bda48015a4d228c2ef4f192ab9e5a7af69))
* **messaging:** add ConversationSummary read DTO and Ecto schema ([3280ab5](https://github.com/MaxPayne89/prime-youth/commit/3280ab50e2b22f2659bd8eb5f8f70bddf73be43e))
* **messaging:** add integration event promotions for CQRS projections ([60644b3](https://github.com/MaxPayne89/prime-youth/commit/60644b3ea9e5caf4d65920df8eb0d351fed87ff3))
* **messaging:** add read port and ConversationSummariesRepository ([185c256](https://github.com/MaxPayne89/prime-youth/commit/185c256b60caab0bbc85d88bcb41b6dc88862ec2))
* pass subscription tier through registration event to provider creation ([cd4d190](https://github.com/MaxPayne89/prime-youth/commit/cd4d19086163684a0bf81f2a49606abf3a3117d6))
* **program_catalog:** add season field to Program ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([a7f22b9](https://github.com/MaxPayne89/prime-youth/commit/a7f22b91b3ae47d7f1c2ff97a7960616049fad06))
* **program-catalog:** add program_listings read model table ([ab21638](https://github.com/MaxPayne89/prime-youth/commit/ab21638ad110da7abb87a925f8ed1ec239e8f76d))
* **program-catalog:** add program_updated domain event for CQRS projections ([c262d1b](https://github.com/MaxPayne89/prime-youth/commit/c262d1b1cc8dc094891ecf2b5e56563c22f2c3a3))
* **program-catalog:** add program_updated integration event promotion ([69877ce](https://github.com/MaxPayne89/prime-youth/commit/69877ceaf10d15d85ab7c61b8baf5c1347a8a085))
* **program-catalog:** add ProgramListing read DTO and Ecto schema ([e88e1ba](https://github.com/MaxPayne89/prime-youth/commit/e88e1bafb5bf98c36cfd8e22b028e315f14c8204))
* **program-catalog:** add ProgramListingsProjection GenServer ([b5ba209](https://github.com/MaxPayne89/prime-youth/commit/b5ba209d5340de806666a83d1be4ed10ec95ff88))
* **program-catalog:** add read port and ProgramListingsRepository ([e61069e](https://github.com/MaxPayne89/prime-youth/commit/e61069e13993ebc0c12b00fff02b0897b99c96e1))
* publish bulk_invites_imported event after CSV import ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([194be2f](https://github.com/MaxPayne89/prime-youth/commit/194be2f9b45256fc21087e7dc3ef60f0ed382cda))
* publish domain event on subscription tier change ([a7b4968](https://github.com/MaxPayne89/prime-youth/commit/a7b4968e53d66f6267e0dcaff57c5ae3784361ed))
* publish domain event on subscription tier change ([#271](https://github.com/MaxPayne89/prime-youth/issues/271)) ([53f3e10](https://github.com/MaxPayne89/prime-youth/commit/53f3e10a19901c6619bded3614b7d1ab8b6b5275))
* register invite email handler on enrollment event bus ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([cd9bf85](https://github.com/MaxPayne89/prime-youth/commit/cd9bf85bb9aaf29bd8bfdd2d3d70d5d1714b67a0))
* register verification status handlers on Provider DomainEventBus ([3c08d87](https://github.com/MaxPayne89/prime-youth/commit/3c08d870db772ee48a6507007e2a8f49569584b0))
* render cover image in program detail hero with gradient fallback ([99b45b3](https://github.com/MaxPayne89/prime-youth/commit/99b45b35ba0b5ce7011ff3614470ca4ee0bc4f1d))
* render cover image on program card with gradient fallback ([b8b28b6](https://github.com/MaxPayne89/prime-youth/commit/b8b28b6eeceb798c256230252bb924e1e0c08ecf)), closes [#196](https://github.com/MaxPayne89/prime-youth/issues/196)
* show eligibility feedback in booking flow ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([dd1f2e7](https://github.com/MaxPayne89/prime-youth/commit/dd1f2e74779f635925818e21620d48e584e8251f))
* show registration status on program detail page ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([16446ca](https://github.com/MaxPayne89/prime-youth/commit/16446ca5a10ad04d3475a7f7a3ad46c6828dccc2))
* switch read use cases to CQRS read models ([581c283](https://github.com/MaxPayne89/prime-youth/commit/581c2836fe9f010f4bfe5746337205cff9caa110))
* update program display to use structured scheduling fields ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([3b363f0](https://github.com/MaxPayne89/prime-youth/commit/3b363f01fb9b6ac266543158c33d6b5a99d6fa01))
* update ProgramMapper for scheduling fields ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([5e6fb91](https://github.com/MaxPayne89/prime-youth/commit/5e6fb91a2447c9619a84fab20979af608cdcbd99))
* update test factories for scheduling fields ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([3bc86d6](https://github.com/MaxPayne89/prime-youth/commit/3bc86d667139fd65288df17e103cdf727f30ca4f))
* **web:** add InviteClaimController and /invites/:token route ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([12eab68](https://github.com/MaxPayne89/prime-youth/commit/12eab68689987862cf723bde310097bde28d66e8))
* **web:** add tabbed roster modal with invites, CSV upload, and actions ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([752934f](https://github.com/MaxPayne89/prime-youth/commit/752934f31e3ba357621b581379353e5bbf17ad6b))
* wire Edit button with modal reuse and UpdateProgram ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([51c0fdb](https://github.com/MaxPayne89/prime-youth/commit/51c0fdb24a49eadbdb776d9756e5d3fb319285b0))
* wire EnrollmentPolicy into config and context facade ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([aa1bb29](https://github.com/MaxPayne89/prime-youth/commit/aa1bb29b1caf8bf3c27f6269c9cd8d0ab260a95a))
* wire Preview link, add phx-click to Edit/Roster, remove Duplicate ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([7cba154](https://github.com/MaxPayne89/prime-youth/commit/7cba154a449ce71fe6d126d709ef8a0b94f75e62))


### Bug Fixes

* add :warning flash kind to fix silently swallowed warnings ([7fb7697](https://github.com/MaxPayne89/prime-youth/commit/7fb76975adf037e671ea2e0e96dcb6cfc1fec085))
* add active-state feedback to provider dashboard buttons ([3a212ee](https://github.com/MaxPayne89/prime-youth/commit/3a212eeb88b22213e3982f1e8e98447d0e3b98b5))
* add active-state press feedback to provider dashboard buttons ([b7e30b6](https://github.com/MaxPayne89/prime-youth/commit/b7e30b6a0c3c72350705d4242e5d4eebeecd9930)), closes [#143](https://github.com/MaxPayne89/prime-youth/issues/143)
* add case-collision detection and gettext field labels in CSV import ([58869f8](https://github.com/MaxPayne89/prime-youth/commit/58869f846f3a7660e830e09594535b87658b02a9))
* add contents read permission to Security workflow ([f7f01d2](https://github.com/MaxPayne89/prime-youth/commit/f7f01d2936512c7f36fc29d77424abcf6235719a))
* add downloads dir to static paths for CSV template serving ([c3c1731](https://github.com/MaxPayne89/prime-youth/commit/c3c1731e1b1cfd3e756f761acb3183f23743aa26)), closes [#224](https://github.com/MaxPayne89/prime-youth/issues/224)
* add missing Logger metadata keys for enrollment import ([bac8c86](https://github.com/MaxPayne89/prime-youth/commit/bac8c8627804fd90edca0a1f0b1683320e51f0eb))
* add missing Logger metadata keys for upload crash logging ([d3e01eb](https://github.com/MaxPayne89/prime-youth/commit/d3e01ebf7114eb17459ef31eeeab07fb79ccb242))
* add missing Logger metadata keys to formatter whitelist ([c47df3d](https://github.com/MaxPayne89/prime-youth/commit/c47df3d171d3e6271a5d45734443f015d0baf5fa))
* add nil guards for booking config and price formatting ([cb7ec12](https://github.com/MaxPayne89/prime-youth/commit/cb7ec123272d2db4fc471e19594e2c834bde5e30))
* add security-events write permission to Security workflow ([e17d85f](https://github.com/MaxPayne89/prime-youth/commit/e17d85f03c468687d9b6c93064a7db9907fbedba))
* add security-events write permission to Security workflow ([4605aef](https://github.com/MaxPayne89/prime-youth/commit/4605aefb815a03c574a6bcc78382e57984035a73)), closes [#268](https://github.com/MaxPayne89/prime-youth/issues/268)
* address CQRS review issues I1–I10 ([c66b612](https://github.com/MaxPayne89/prime-youth/commit/c66b612e1225d9ce0ab7cecd7c556e2b2d4b019d))
* address CQRS review suggestions S2–S8 ([8436d27](https://github.com/MaxPayne89/prime-youth/commit/8436d27a141bd9f57242ca55de690d71510e8251))
* address critical and important architecture review findings ([91c0834](https://github.com/MaxPayne89/prime-youth/commit/91c083434ce6b2d4653f814fc4a0e59e79ad6799))
* address PR [#197](https://github.com/MaxPayne89/prime-youth/issues/197) review comments on invite email pipeline ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([1bc431d](https://github.com/MaxPayne89/prime-youth/commit/1bc431d378f8d46bf5cfd5fb007a53fdcdd8e333))
* address PR [#210](https://github.com/MaxPayne89/prime-youth/issues/210) review comments on CQRS projections ([efc1f1f](https://github.com/MaxPayne89/prime-youth/commit/efc1f1f0ee8e10b8c9f450edf047e308e7e02c69))
* address PR [#252](https://github.com/MaxPayne89/prime-youth/issues/252) review comments ([18d2f64](https://github.com/MaxPayne89/prime-youth/commit/18d2f6424aa3be59ab6bbe307a10060cbc4f5276))
* address PR review — add tier error display and use shared test helper ([8f02fb9](https://github.com/MaxPayne89/prime-youth/commit/8f02fb9e34579347073ad629d5eececd766dc8b4))
* address PR review — guard tier functions and fix i18n in format_media ([b0708e2](https://github.com/MaxPayne89/prime-youth/commit/b0708e23a6144845cdb4ab65fa51c75bccd5697a))
* address PR review feedback for invite claim saga ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([649e4fd](https://github.com/MaxPayne89/prime-youth/commit/649e4fdc4f2d3e9285b1e47af3b35214d965dd89))
* address PR review feedback on icon_path removal ([4940490](https://github.com/MaxPayne89/prime-youth/commit/4940490aedf6935954f43be15ccfa0532dc5db47))
* address PR review feedback on icon_path removal ([ffed2ad](https://github.com/MaxPayne89/prime-youth/commit/ffed2ad8c08a6397a42bcf906f400c7d71912cdf))
* address suggestion-level architecture review findings ([#8](https://github.com/MaxPayne89/prime-youth/issues/8)-25) ([3e99e08](https://github.com/MaxPayne89/prime-youth/commit/3e99e080e8db56241d24a28a9cf5f913f9e35b80))
* align test names with assertions in dashboard tests ([0e8e866](https://github.com/MaxPayne89/prime-youth/commit/0e8e86610b531ae314269a6085d95bd1acbc74f5))
* auto-verify/unverify provider on document review ([3b3a306](https://github.com/MaxPayne89/prime-youth/commit/3b3a306ee0af8d730cf780e86e5fdbd2e1a7ebc5))
* clear textarea after sending message ([5c8169f](https://github.com/MaxPayne89/prime-youth/commit/5c8169f0fffa080725a86d2a1381a46e3c0ea441))
* clear textarea value after sending message ([747c26b](https://github.com/MaxPayne89/prime-youth/commit/747c26bdf06d507b3f28631de66edb1017dca7f3)), closes [#228](https://github.com/MaxPayne89/prime-youth/issues/228)
* consolidate nil fallback and untrack beads backup artifacts ([14d2c3b](https://github.com/MaxPayne89/prime-youth/commit/14d2c3bee11c99d255c831a0e5acfaa31c6c2fe8))
* CSV template download returns 404 ([13d2abe](https://github.com/MaxPayne89/prime-youth/commit/13d2abe9d4ad25e0e9a1aed54fb339784f8728ae))
* display cover image on program cards and detail page ([22a12ae](https://github.com/MaxPayne89/prime-youth/commit/22a12ae05fd461179dcb72671a34fca95a1fc3be))
* eliminate SQL string interpolation in bulk_assign_tokens ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([463894c](https://github.com/MaxPayne89/prime-youth/commit/463894cd953dd311bffff7b6ba27965b8f536795))
* **enrollment:** address PR [#199](https://github.com/MaxPayne89/prime-youth/issues/199) review comments — authz, scoping, docs ([0dc3d68](https://github.com/MaxPayne89/prime-youth/commit/0dc3d684710e8ea336b7051b19877976f55c858c))
* **enrollment:** address PR review findings ([#195](https://github.com/MaxPayne89/prime-youth/issues/195)) ([49a6716](https://github.com/MaxPayne89/prime-youth/commit/49a6716e8281cc800a3601111ac55f7449dd66f5))
* **enrollment:** address test-drive findings — mobile table, dev URLs, CSV hint ([37180b3](https://github.com/MaxPayne89/prime-youth/commit/37180b3be2cd506b9af29ca48a62290afd3f6268))
* **enrollment:** correct behaviour, aggregate type, and handler priority in invite claim saga ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([be9fe20](https://github.com/MaxPayne89/prime-youth/commit/be9fe200ffc2a4e60a1e6940ca13caf9bad5c610))
* **enrollment:** handle malformed CSV and case-insensitive booleans ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([8cc16a3](https://github.com/MaxPayne89/prime-youth/commit/8cc16a3c3a0d042e5af6cfc0782cadf9cb09b716))
* **enrollment:** harden CSV import helpers with tagged tuples and UUID guard ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([adee78a](https://github.com/MaxPayne89/prime-youth/commit/adee78a6e2d3eb2cc1ba55e5b87207fa66ec3218))
* **enrollment:** harden error handling, config, and event semantics ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([88933dc](https://github.com/MaxPayne89/prime-youth/commit/88933dc7c987c8ec51e3b2a62997f2f0641b5f3f))
* **enrollment:** make bulk invite unique index case-insensitive ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([2f7cd12](https://github.com/MaxPayne89/prime-youth/commit/2f7cd124aa6f3aea75eebf499061012e0c422c4e))
* **enrollment:** preserve row index in batch errors, guard empty programs ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e4718c4](https://github.com/MaxPayne89/prime-youth/commit/e4718c47b3d0f2b2bbf2ce4abbf41d15b58728ad))
* **enrollment:** remove silent nil fallback on program.price ([#195](https://github.com/MaxPayne89/prime-youth/issues/195)) ([631e3da](https://github.com/MaxPayne89/prime-youth/commit/631e3da3bca11cc4b8c869bd39e83a125cf5dace))
* **enrollment:** replace bare pattern matches with proper error handling ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([a3ef4e9](https://github.com/MaxPayne89/prime-youth/commit/a3ef4e90b3882eb48f9de0ca91ff805693592676))
* **enrollment:** simplify pricing to use program.price directly ([#195](https://github.com/MaxPayne89/prime-youth/issues/195)) ([5a53b0d](https://github.com/MaxPayne89/prime-youth/commit/5a53b0d0e57c3e16c500420d73a8485db1bdf0c0))
* **enrollment:** use program.price directly as total ([#195](https://github.com/MaxPayne89/prime-youth/issues/195)) ([053fb26](https://github.com/MaxPayne89/prime-youth/commit/053fb26ad225356cd68337df3a792f17e416b86e))
* export shared NotifyLiveViews from Shared boundary ([3c05883](https://github.com/MaxPayne89/prime-youth/commit/3c05883ab4a9cfea794348d9866f45d138669664))
* flash messages hidden under navbar ([80b25d6](https://github.com/MaxPayne89/prime-youth/commit/80b25d679769a374f9a2f05a3b73009ca1d9cd7c))
* handle BOM, case-insensitive programs, and error labels in CSV import ([e0def48](https://github.com/MaxPayne89/prime-youth/commit/e0def4847ff6f2283ee6677bc080dc6ca1817665))
* handle BOM, case-insensitive programs, and error labels in CSV import ([caafdf5](https://github.com/MaxPayne89/prime-youth/commit/caafdf51a17712f45485f8397df1ac1731f15922)), closes [#243](https://github.com/MaxPayne89/prime-youth/issues/243)
* handle nil other_participant_name in conversation_card component ([70c13a6](https://github.com/MaxPayne89/prime-youth/commit/70c13a670f920f310c08f6fff3c26c26707a7b58))
* handle nil other_participant_name in conversation_card component ([787510e](https://github.com/MaxPayne89/prime-youth/commit/787510e88b4cacf9e3a0534f09eae2f125d5d861)), closes [#241](https://github.com/MaxPayne89/prime-youth/issues/241)
* harden CQRS projections against data loss, crashes, and unsafe ops ([3d64dec](https://github.com/MaxPayne89/prime-youth/commit/3d64decd314c2a456a6bcb28cd38deef55bf1be5))
* improve date range display and whitespace handling ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([dd43034](https://github.com/MaxPayne89/prime-youth/commit/dd430346cadd40380fad7c95f7e394b540378c97))
* improve observability for silent failure locations ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([212dce5](https://github.com/MaxPayne89/prime-youth/commit/212dce586ca187e2ca6176bce3fb82e664794a1c))
* include cover_image_url in programs listing map ([f1d9926](https://github.com/MaxPayne89/prime-youth/commit/f1d99267190340c2d10601e07c0e66603bb25639))
* include headshot_url in staff member edit changeset ([#231](https://github.com/MaxPayne89/prime-youth/issues/231)) ([eb8bf20](https://github.com/MaxPayne89/prime-youth/commit/eb8bf20a5b7b545ec0dc9e5b87b2a015cbdd75c9))
* log nil subscription tier fallback and test same_tier handler ([7d31dfb](https://github.com/MaxPayne89/prime-youth/commit/7d31dfb7e23128bab16449ddad41965bb9e1958e))
* **messaging:** exclude own messages from unread count in bootstrap ([3da5778](https://github.com/MaxPayne89/prime-youth/commit/3da5778364d58e6dab7267c0d3d5b12e9cdfa86c))
* move extracted staff helpers after all handle_event clauses ([bedde02](https://github.com/MaxPayne89/prime-youth/commit/bedde02105cc4b88b2d051cf45afbb9f63b1c2a8))
* normalize qualifications string before changeset in validate_staff ([c6c75b5](https://github.com/MaxPayne89/prime-youth/commit/c6c75b510b7122e2cc85431d0980a76cabac9ebd))
* normalize qualifications string before changeset in validate_staff ([08ef58e](https://github.com/MaxPayne89/prime-youth/commit/08ef58ee224727b97b29f23d97178c4950227442)), closes [#142](https://github.com/MaxPayne89/prime-youth/issues/142)
* preserve enrollment count after program edit ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([c40c361](https://github.com/MaxPayne89/prime-youth/commit/c40c361560db8bb60fa88360720f4d3962b5aaea))
* prevent phantom capacity display on failed policy save ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([b46b4b4](https://github.com/MaxPayne89/prime-youth/commit/b46b4b40d2be98e18f4205a20ce8a1fd05df70db))
* **program-catalog:** use VerifiedProviders for bootstrap provider_verified ([ea4492a](https://github.com/MaxPayne89/prime-youth/commit/ea4492a3dd49c41b882debb447892dd39e9065db))
* propagate handler errors + dedup test fixtures ([9d7bca8](https://github.com/MaxPayne89/prime-youth/commit/9d7bca8d08784d416ae72df7441d9231bcb4d48d))
* remove catch-all handle_info from messaging LiveView macros ([632b64d](https://github.com/MaxPayne89/prime-youth/commit/632b64d57f3dacacbcc0ce73db53c5a7415ca15c))
* remove dead [@current](https://github.com/current)_user assign from BookingLive ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([46bed14](https://github.com/MaxPayne89/prime-youth/commit/46bed14c4298226754c975bf4f401061df724abd))
* remove Ecto.Changeset type from domain port ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([3ef9bd5](https://github.com/MaxPayne89/prime-youth/commit/3ef9bd5b22b1a99e2e36a4e6dd812930c92434fd))
* remove stacking context trapping flash messages under navbar ([b4d843c](https://github.com/MaxPayne89/prime-youth/commit/b4d843c2892d9ee0461e78ea970f6db813504138)), closes [#232](https://github.com/MaxPayne89/prime-youth/issues/232)
* replace hero-blue-500 with hero-blue-600 for WCAG AA contrast ([f49e734](https://github.com/MaxPayne89/prime-youth/commit/f49e734526f65fad2c5c3cde99f34e8e78c7d8b4)), closes [#227](https://github.com/MaxPayne89/prime-youth/issues/227)
* replace stale prime-cyan/magenta/yellow classes with brand colors ([a0f81b7](https://github.com/MaxPayne89/prime-youth/commit/a0f81b7a661f2f513418d2ff3f8ff5e0c860826b)), closes [#227](https://github.com/MaxPayne89/prime-youth/issues/227)
* replace String.to_existing_atom with safe tier cast ([b7e00e5](https://github.com/MaxPayne89/prime-youth/commit/b7e00e58207b66d915436d93f4d12f8bbae4b21f))
* require status change in transition_changeset/2 ([297ee1c](https://github.com/MaxPayne89/prime-youth/commit/297ee1c1536ccc63478b54034d2bfecad9da412c))
* resolve architecture review issues for enrollment capacity ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([8e0b04d](https://github.com/MaxPayne89/prime-youth/commit/8e0b04d88c1092843de8d4c1428dfc1ba91a398c))
* resolve architecture review suggestions [#12](https://github.com/MaxPayne89/prime-youth/issues/12)-14 ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([7455943](https://github.com/MaxPayne89/prime-youth/commit/7455943b403773458b8080a355855547dbb50623))
* resolve CI failure and warnings in invite claim and test mocks ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([20a3067](https://github.com/MaxPayne89/prime-youth/commit/20a306784784878caa11bb9b23052c77cfe7da94))
* resolve credo --strict warnings for logger metadata and list assertion ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([987b0aa](https://github.com/MaxPayne89/prime-youth/commit/987b0aa74d77aad85a003e0eb08090f0dece8d64))
* resolve critical runtime bugs in Family Programs section ([#154](https://github.com/MaxPayne89/prime-youth/issues/154)) ([8b289a7](https://github.com/MaxPayne89/prime-youth/commit/8b289a72cb4e3e03860d879cad2b2fd43757f849))
* resolve important architecture review issues [#4](https://github.com/MaxPayne89/prime-youth/issues/4)-8 ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([a2fd39b](https://github.com/MaxPayne89/prime-youth/commit/a2fd39b2d9376c9c4b306ca066c52dc8c7b64cca))
* resolve parent profile for enrollment queries and add integration tests ([#154](https://github.com/MaxPayne89/prime-youth/issues/154)) ([7dddab8](https://github.com/MaxPayne89/prime-youth/commit/7dddab8b15e70d60f2d86ad2309b2d56793a1be9))
* resolve saga test race condition and add missing subscription tests ([a2de0de](https://github.com/MaxPayne89/prime-youth/commit/a2de0deff4c5cd7b9f8db9c9ffeff018a32ac86a))
* resolve scheduling architecture issues ([#146](https://github.com/MaxPayne89/prime-youth/issues/146)) ([171a1a1](https://github.com/MaxPayne89/prime-youth/commit/171a1a1d516c4497a4f95f296b53f7d2b7bfdaf8))
* resolve TODO comments and update dependencies ([be60e88](https://github.com/MaxPayne89/prime-youth/commit/be60e88caf9651ad9d3de22eda3075d8f959272a))
* show warning flash on cover upload failure instead of blocking save ([0a8e856](https://github.com/MaxPayne89/prime-youth/commit/0a8e856fc0048d83cd30363fb6e0b81db004c3d7))
* staff member headshot not updating on edit ([dd12a19](https://github.com/MaxPayne89/prime-youth/commit/dd12a19f61a46ce5de6ad324311cafb48ead4ae3))
* suppress sobelow Traversal.FileModule false positives ([7aac9a6](https://github.com/MaxPayne89/prime-youth/commit/7aac9a698516fbab44320d235f4256fdff7ee2e6))
* **test:** disable VerifiedProviders projection in test env ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([2e11355](https://github.com/MaxPayne89/prime-youth/commit/2e11355646560a802f9505a5959d9d9206eeb47c))
* **test:** isolate child, provider, and verification document tests from pre-existing data ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([23b88e6](https://github.com/MaxPayne89/prime-youth/commit/23b88e6210b1301ec90d364e02d18a13c2b0e368))
* **test:** isolate paginated program tests from pre-existing data ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([a614076](https://github.com/MaxPayne89/prime-youth/commit/a614076c8863770156523a04c9d180e7f98865f5))
* unread message count badge not visible ([9d092c6](https://github.com/MaxPayne89/prime-youth/commit/9d092c635f796d5d19aa68db84dad19a95999224))
* unwrap consume_uploaded_entries results and add crash protection ([454ef7f](https://github.com/MaxPayne89/prime-youth/commit/454ef7f9f5c6587425aca1197ba61ea9e89da75f))
* unwrap upload results and add crash protection ([c76f891](https://github.com/MaxPayne89/prime-youth/commit/c76f891e2b57459b57e846dab96f0aafe2d6096b))
* use current_scope.user.id for check-in/out FK integrity ([2f0a540](https://github.com/MaxPayne89/prime-youth/commit/2f0a5403f885d3d4e21e13ddda411a911fe847b8))
* use DaisyUI theme colors for unread message count badges ([3d858c3](https://github.com/MaxPayne89/prime-youth/commit/3d858c3df592b43973fbf82a06dcd98d1ca703cc)), closes [#229](https://github.com/MaxPayne89/prime-youth/issues/229)
* use program price directly as enrollment total ([c6986b2](https://github.com/MaxPayne89/prime-youth/commit/c6986b2d49f05e0b79b574ec6f458e53428fb806))
* use push_event to clear textarea after message send ([a5cb636](https://github.com/MaxPayne89/prime-youth/commit/a5cb636e60a890e58d9ab8d60509a23bef93fe65)), closes [#228](https://github.com/MaxPayne89/prime-youth/issues/228)
* use realistic UUIDs in MessagingLiveHelper tests ([1358886](https://github.com/MaxPayne89/prime-youth/commit/1358886344cef499b61449d755da628f534a9b22))
* use registration_period struct for edit form population ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([1b2f45e](https://github.com/MaxPayne89/prime-youth/commit/1b2f45e8bec27ab0700382768f9edca874aabedf))
* use tagged error tuples in cast_provider_tier and remove tier_label catch-all ([415c675](https://github.com/MaxPayne89/prime-youth/commit/415c675cbc1cd8c6523295bcf8b4d76ce5d9c520))
* use text-error-content instead of text-white on unread badges ([27a39f7](https://github.com/MaxPayne89/prime-youth/commit/27a39f742683b0d2048c43d2102b84927a228871))
* white-on-white text in message bubbles ([2bcc023](https://github.com/MaxPayne89/prime-youth/commit/2bcc023c44c46eadaa8fa6f91610e1cbd9b658d4))
* wire up Add Child button and View All link on parent dashboard ([197d3d7](https://github.com/MaxPayne89/prime-youth/commit/197d3d761f234bb4ab8bf87615de22b402ecce50)), closes [#225](https://github.com/MaxPayne89/prime-youth/issues/225)
* wire up Add Child button on parent dashboard ([fe17b36](https://github.com/MaxPayne89/prime-youth/commit/fe17b3668077bd9e8abf74aa03a8ddddbe1ced6d))


### Code Refactoring

* convert family programs to LiveView stream ([#154](https://github.com/MaxPayne89/prime-youth/issues/154)) ([9efe84c](https://github.com/MaxPayne89/prime-youth/commit/9efe84ce99ed0abff2ce5e285c668c42bba288f3))
* deduplicate messaging LiveView callbacks ([1f29df6](https://github.com/MaxPayne89/prime-youth/commit/1f29df6fb5f59880aa46be328f545ee0a54f930c))
* deduplicate messaging LiveView callbacks via __using__ macro ([61af8b2](https://github.com/MaxPayne89/prime-youth/commit/61af8b2b4dbbff27807d4320ca3c4cc291cac02a)), closes [#266](https://github.com/MaxPayne89/prime-youth/issues/266)
* **enrollment,family:** extract user accounts port and centralize dispatch error handling ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([dda818f](https://github.com/MaxPayne89/prime-youth/commit/dda818f359598ec07e0d88cb3354120178a6cf67))
* **enrollment:** extract helpers to fix Credo nesting-depth violations ([263675d](https://github.com/MaxPayne89/prime-youth/commit/263675d58b382ffa42e6872f311e720b59ba9193))
* **enrollment:** remove dead fee calculation code ([#195](https://github.com/MaxPayne89/prime-youth/issues/195)) ([4d94097](https://github.com/MaxPayne89/prime-youth/commit/4d940970eea4af11753cfa757cf959edebb29090))
* extract check_title_collisions/1 to flatten nesting in build_context/1 ([9fb84d3](https://github.com/MaxPayne89/prime-youth/commit/9fb84d3ca573dec8bd0394a0c13914a239315519))
* extract duplicated to_domain_list into MapperHelpers ([2727a48](https://github.com/MaxPayne89/prime-youth/commit/2727a487560af247f69a8dc7150626771128ea6b))
* extract duplicated to_domain_list/1 into MapperHelpers ([c02c66c](https://github.com/MaxPayne89/prime-youth/commit/c02c66cc9d9cf3cde858dfedc265885046a4c112)), closes [#239](https://github.com/MaxPayne89/prime-youth/issues/239)
* extract EnqueueInviteEmails use case from event handler ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([6b9e769](https://github.com/MaxPayne89/prime-youth/commit/6b9e769b04e89d326e1362a509388e43d9436929))
* extract EnrollmentClassifier domain service ([#154](https://github.com/MaxPayne89/prime-youth/issues/154)) ([5de95bf](https://github.com/MaxPayne89/prime-youth/commit/5de95bf9c91cc0e0a0b293f5fcb44944b3558375))
* extract save_staff branches to reduce complexity and nesting ([d209571](https://github.com/MaxPayne89/prime-youth/commit/d2095719a1b73de8cc2bd0c41e4005cf283e1908))
* extract shared badge and hero overlay components ([2703f07](https://github.com/MaxPayne89/prime-youth/commit/2703f070209f23e295318adf5222ecee847e7725))
* extract shared MapperHelpers ([37d4690](https://github.com/MaxPayne89/prime-youth/commit/37d469026ad8b235058ba90009dad5ed62f409a1))
* extract shared MapperHelpers from Family/Provider/Enrollment ([a78af2e](https://github.com/MaxPayne89/prime-youth/commit/a78af2ec39b50563b0bbdc9927cbaf5faba6b115)), closes [#214](https://github.com/MaxPayne89/prime-youth/issues/214)
* extract shared normalize_subscription_tier from repositories ([91eeb67](https://github.com/MaxPayne89/prime-youth/commit/91eeb670899b0d99339c4a00ee69756e1a351dc4))
* extract shared normalize_subscription_tier from repositories ([337942c](https://github.com/MaxPayne89/prime-youth/commit/337942c1b2688ceba101841d744c7a3dafe117dc)), closes [#220](https://github.com/MaxPayne89/prime-youth/issues/220)
* extract shared NotifyLiveViews handler to eliminate duplication ([f3b7e25](https://github.com/MaxPayne89/prime-youth/commit/f3b7e2561ed7baf8e576597ff6bee7db1d992e63))
* extract shared NotifyLiveViews handler to eliminate duplication ([8fdd19d](https://github.com/MaxPayne89/prime-youth/commit/8fdd19d8bcf28f8a1827a6455a43b391cebb4cf1)), closes [#253](https://github.com/MaxPayne89/prime-youth/issues/253)
* extract shared TierPresenter for tier display data ([2613ea9](https://github.com/MaxPayne89/prime-youth/commit/2613ea953b0d36cbb8a1f857555866e1211779a0)), closes [#270](https://github.com/MaxPayne89/prime-youth/issues/270)
* extract shared TierPresenter to eliminate duplicated tier display data ([419666d](https://github.com/MaxPayne89/prime-youth/commit/419666d63c315c97bc76caf4351b45a28e112b81))
* **family:** route guardian operations through port ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([e7e5eec](https://github.com/MaxPayne89/prime-youth/commit/e7e5eec6d0e3218baf4c6a0d2f1c14d5cea0168d))
* fix architecture review findings for registration period ([#147](https://github.com/MaxPayne89/prime-youth/issues/147)) ([eb15af3](https://github.com/MaxPayne89/prime-youth/commit/eb15af30e716a69384f93b9f8de3ce14712809c1))
* fix architecture review issues for participant restrictions ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([8d10dad](https://github.com/MaxPayne89/prime-youth/commit/8d10dada872a0a8abd09c45cf80b83b59e177a15))
* fix credo --strict issues ([d008038](https://github.com/MaxPayne89/prime-youth/commit/d0080384749ab9b798dca3934ab0a331cebc133d))
* fix credo --strict issues in enrollment and dashboard ([#151](https://github.com/MaxPayne89/prime-youth/issues/151)) ([23bc3f4](https://github.com/MaxPayne89/prime-youth/commit/23bc3f40a4df9660f9e3a93aee32db1a06f4d061))
* fix credo complexity issues in roster and edit handlers ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([483f921](https://github.com/MaxPayne89/prime-youth/commit/483f92128a9cea6e516aca78c5093ae23a77c73b))
* hide pricing section on homepage ([#178](https://github.com/MaxPayne89/prime-youth/issues/178)) ([61e5a65](https://github.com/MaxPayne89/prime-youth/commit/61e5a658032a2dcfc562e529d737a1925bd53f58))
* improve readability of compile_env! calls in ListProgramEnrollments ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([e38c52e](https://github.com/MaxPayne89/prime-youth/commit/e38c52e1257c12d01748f6c4fd658552420e7084))
* loosen typespec on MapperHelpers.to_domain_list/2 ([fc2c7f5](https://github.com/MaxPayne89/prime-youth/commit/fc2c7f58c23b1fc47e653b017f6edb01696cdf10))
* make port contracts type-safe and extend ProgramMapper.to_schema/1 with provider_id ([90cb430](https://github.com/MaxPayne89/prime-youth/commit/90cb430295a932c508c881ea89da125759b9a88f))
* move icon_name/1 from Shared.Categories to ProgramPresenter ([688a708](https://github.com/MaxPayne89/prime-youth/commit/688a708f53c4dde35b3631ad2671c2aaa3dcbd8d))
* remove hardcoded data and wire to config/domain ([65099ad](https://github.com/MaxPayne89/prime-youth/commit/65099ad6a2b6bcde51a2163f1e5e35d00b075491))
* remove icon_path from Program domain model ([d1cb115](https://github.com/MaxPayne89/prime-youth/commit/d1cb1150666272cdc8836b99451c68ac750e8971))
* remove icon_path from read model, schemas, projections, and repository ([412c650](https://github.com/MaxPayne89/prime-youth/commit/412c650197e21c0915e5208a1a2adf681e3aa46d))
* remove icon_path, derive program icons from category ([1dc1999](https://github.com/MaxPayne89/prime-youth/commit/1dc19992fe369ef0489873f1c53e54221dbc89d8))
* remove spots_available from Program, migrate to enrollment policies ([#149](https://github.com/MaxPayne89/prime-youth/issues/149)) ([55940cd](https://github.com/MaxPayne89/prime-youth/commit/55940cdf85f485c816b8fc11ae17534c6d2d4de3))
* replace child parent_id with children_guardians join table ([c4387fe](https://github.com/MaxPayne89/prime-youth/commit/c4387fe261210b870014954d7cd0e26fe168ff13))
* replace icon_path SVG rendering with heroicon components ([e88ec0d](https://github.com/MaxPayne89/prime-youth/commit/e88ec0d2225f15c97d528ddc0061ba8244418384))
* return domain models from invite repository ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([1754a97](https://github.com/MaxPayne89/prime-youth/commit/1754a97141b122fd73a4ae3469c3af42988e7883))
* route CreateProgram use case through Program aggregate, update repository and integration tests ([9270f7f](https://github.com/MaxPayne89/prime-youth/commit/9270f7f25ed3143f9a61b95939d01f907ddae130))
* use compile_env! for DI in ListProgramEnrollments ([#145](https://github.com/MaxPayne89/prime-youth/issues/145)) ([b55e214](https://github.com/MaxPayne89/prime-youth/commit/b55e214eeaaaa2af8fe7afe45052dff21e334f90))
* use compile_env! module attributes in enrollment use cases ([e3a7f05](https://github.com/MaxPayne89/prime-youth/commit/e3a7f05f19c50dbb54f589a59c9c1e362e25b650))
* use compile_env! module attributes in enrollment use cases ([39a3422](https://github.com/MaxPayne89/prime-youth/commit/39a342213e6e9939a4cccba7166d5909ca39805f))
* use domain model in SendInviteEmailWorker ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([03c251e](https://github.com/MaxPayne89/prime-youth/commit/03c251e7bad70cb2e7df946dd228e49f013082f7))
* use shared mailer_defaults config in UserNotifier ([#176](https://github.com/MaxPayne89/prime-youth/issues/176)) ([9d093c0](https://github.com/MaxPayne89/prime-youth/commit/9d093c0a58408247f3a2f1dc19123194a17e4054))


### Dependencies

* update credo, ecto_sql, error_tracker, phoenix_live_view ([051889b](https://github.com/MaxPayne89/prime-youth/commit/051889b2a9494df2fac82fa3fdd473827ba43b38))

## [Unreleased]

## [0.2.0] - 2024-09-11

### Fixed
- **Mobile Mockups**: Resolved header icon visibility in iPhone 14 mockup frame
  - Removed problematic margin-right causing bell and gear icons to overflow
  - Added responsive sizing with clamp() for dynamic icon scaling (36-44px)
  - Implemented flex-shrink: 0 to prevent icon compression
  - Updated header padding system for consistent mobile spacing
  - Icons now remain fully visible across all phone frame sizes (300-375px)

### Added
- **Documentation**: Comprehensive non-developer friendly mockup viewing guide
- **Documentation**: Quick start instructions for accessing app mockups
- **README**: Step-by-step mockup navigation guide for stakeholders

### Enhanced
- **Mobile Mockups**: Improved responsive design system for better cross-device compatibility
- **User Experience**: Better touch targets and mobile-first responsive design

## [0.1.0] - 2024-09-10

### Added
- **Mobile Mockups**: Complete responsive phone mockup system with sleek scaling
- **Design System**: Comprehensive UI system with interactive tooling
- **UI Components**: Advanced interactions and dark mode support
- **Navigation**: Improved spacing and visual hierarchy with vibrant borders
- **Mockup System**: Interactive phone frame with multiple screen demonstrations
- **Theme System**: Dark/light mode toggle with persistent storage
- **Responsive Design**: Mobile-first approach with clamp() sizing functions
- **Animation System**: Smooth transitions and micro-interactions

### Infrastructure
- **Project Setup**: Initial monorepo structure with backend and mobile directories
- **Build System**: Basic development environment with CSS/JS organization
- **Documentation**: Foundational README and project structure documentation
