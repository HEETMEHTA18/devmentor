# Development Checklist

## Phase 1: Foundation
- [ ] Finalize repository structure.
- [ ] Set up Flutter theme tokens and glass components.
- [ ] Set up GoRouter navigation and app shell.
- [ ] Create FastAPI project skeleton.
- [ ] Configure environment variables and secrets handling.

## Phase 2: Authentication
- [ ] Implement GitHub OAuth login.
- [ ] Implement Google OAuth login.
- [ ] Implement email login and registration.
- [ ] Issue and refresh JWT tokens.
- [ ] Secure token storage in Flutter.

## Phase 3: GitHub Data and Profiles
- [ ] Sync GitHub profile data.
- [ ] Ingest repositories and contribution activity.
- [ ] Persist normalized GitHub data in PostgreSQL.
- [ ] Build profile summary endpoints.

## Phase 4: Analysis and Intelligence
- [ ] Implement developer scoring.
- [ ] Implement skill extraction and gap detection.
- [ ] Implement README and project complexity scoring.
- [ ] Implement roadmap generation.
- [ ] Implement project and repository recommendation ranking.

## Phase 5: UI Experience
- [ ] Build splash screen.
- [ ] Build onboarding screens.
- [ ] Build login screen.
- [ ] Build dashboard.
- [ ] Build analysis screen.
- [ ] Build repository discovery and repository detail screens.
- [ ] Build roadmap screen.
- [ ] Build mentor chat screen.
- [ ] Build profile, settings, and notifications screens.

## Phase 6: Reliability and Quality
- [ ] Add backend unit tests.
- [ ] Add backend integration tests.
- [ ] Add Flutter widget and golden tests.
- [ ] Add caching and rate limiting.
- [ ] Add structured logging and error handling.

## Phase 7: Deployment
- [ ] Prepare Railway backend deployment.
- [ ] Prepare Neon PostgreSQL migrations.
- [ ] Prepare Firebase Hosting web build.
- [ ] Prepare Supabase storage configuration.
- [ ] Create CI/CD pipelines.

## Release Readiness
- [ ] Verify auth flows end-to-end.
- [ ] Verify GitHub sync and analysis.
- [ ] Verify mentor chat and roadmap generation.
- [ ] Validate dark-mode visuals across devices.
- [ ] Complete app store and release assets.
