# Database Schema

## Design Principles
- Use UUID primary keys.
- Keep core identity data relational.
- Store generated AI payloads in structured JSONB columns when variability is high.
- Track timestamps and soft deletion where needed.
- Index foreign keys and high-read fields.

## Enums
- `auth_provider`: `github`, `google`, `email`
- `recommendation_type`: `repository`, `project`, `open_source`
- `roadmap_status`: `draft`, `active`, `completed`, `archived`
- `chat_role`: `user`, `assistant`, `system`
- `difficulty_level`: `beginner`, `intermediate`, `advanced`
- `completion_status`: `pending`, `in_progress`, `done`, `blocked`

## Tables

### `users`
Primary identity table.

**Columns**
- `id` UUID PK
- `email` varchar unique nullable if OAuth-only
- `name` varchar not null
- `username` varchar unique nullable
- `avatar_url` text nullable
- `bio` text nullable
- `target_role` varchar nullable
- `provider` enum `auth_provider`
- `is_email_verified` boolean default false
- `created_at` timestamptz
- `updated_at` timestamptz
- `last_login_at` timestamptz nullable

**Indexes**
- unique index on `email`
- unique index on `username`
- index on `provider`

### `github_profiles`
Stores synced GitHub account metadata.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `github_id` bigint unique
- `login` varchar unique
- `name` varchar nullable
- `company` varchar nullable
- `location` varchar nullable
- `bio` text nullable
- `public_repos` integer default 0
- `followers` integer default 0
- `following` integer default 0
- `avatar_url` text nullable
- `profile_url` text nullable
- `github_created_at` timestamptz nullable
- `synced_at` timestamptz
- `raw_payload` jsonb nullable

**Indexes**
- unique index on `github_id`
- unique index on `login`
- index on `user_id`

### `repositories`
Stores repositories owned by the user or tracked for analysis.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `github_repo_id` bigint unique nullable
- `owner` varchar
- `name` varchar
- `full_name` varchar unique
- `description` text nullable
- `language` varchar nullable
- `stars_count` integer default 0
- `forks_count` integer default 0
- `watchers_count` integer default 0
- `open_issues_count` integer default 0
- `size_kb` integer default 0
- `is_private` boolean default false
- `is_fork` boolean default false
- `default_branch` varchar nullable
- `repo_url` text nullable
- `created_at_remote` timestamptz nullable
- `updated_at_remote` timestamptz nullable
- `synced_at` timestamptz
- `raw_payload` jsonb nullable

**Indexes**
- unique index on `full_name`
- index on `user_id`
- index on `language`

### `developer_scores`
Stores score snapshots over time.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `score` integer not null
- `grade` varchar nullable
- `trend` varchar nullable
- `delta` integer default 0
- `factors` jsonb not null
- `calculated_at` timestamptz

**Indexes**
- index on `user_id`
- index on `calculated_at desc`

### `skills`
Canonical skill catalog.

**Columns**
- `id` UUID PK
- `name` varchar unique
- `category` varchar nullable
- `description` text nullable
- `created_at` timestamptz

**Indexes**
- unique index on `name`
- index on `category`

### `user_skills`
Join table for user skill ratings.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `skill_id` UUID FK → `skills.id`
- `proficiency` integer not null
- `evidence` jsonb nullable
- `updated_at` timestamptz

**Indexes**
- unique index on `user_id`, `skill_id`

### `skill_gaps`
Stores missing or weak skills identified by analysis.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `skill_id` UUID FK → `skills.id`
- `gap_score` integer not null
- `priority` integer not null
- `reason` text nullable
- `recommendation` text nullable
- `status` enum `completion_status`
- `created_at` timestamptz

**Indexes**
- index on `user_id`
- index on `priority desc`

### `roadmaps`
Stores personalized career plans.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `title` varchar not null
- `target_role` varchar nullable
- `status` enum `roadmap_status`
- `generated_by` varchar nullable
- `summary` text nullable
- `metadata` jsonb nullable
- `created_at` timestamptz
- `updated_at` timestamptz

**Indexes**
- index on `user_id`
- index on `status`

### `roadmap_milestones`
Stores milestone items within a roadmap.

**Columns**
- `id` UUID PK
- `roadmap_id` UUID FK → `roadmaps.id`
- `title` varchar not null
- `description` text nullable
- `order_index` integer not null
- `status` enum `completion_status`
- `due_date` date nullable
- `completed_at` timestamptz nullable
- `metadata` jsonb nullable

**Indexes**
- unique index on `roadmap_id`, `order_index`

### `recommendations`
Stores repository and content recommendations.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `type` enum `recommendation_type`
- `title` varchar not null
- `subtitle` varchar nullable
- `reason` text not null
- `difficulty` enum `difficulty_level`
- `learning_outcome` text nullable
- `time_estimate_hours` integer nullable
- `score` integer not null
- `is_saved` boolean default false
- `is_dismissed` boolean default false
- `metadata` jsonb nullable
- `created_at` timestamptz

**Indexes**
- index on `user_id`
- index on `type`
- index on `score desc`

### `mentor_chats`
Stores chat sessions and thread-level metadata.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `title` varchar nullable
- `model_provider` varchar not null
- `model_name` varchar nullable
- `system_prompt_version` varchar nullable
- `context_snapshot` jsonb nullable
- `created_at` timestamptz
- `updated_at` timestamptz

**Indexes**
- index on `user_id`
- index on `updated_at desc`

### `mentor_messages`
Stores message-level chat content.

**Columns**
- `id` UUID PK
- `chat_id` UUID FK → `mentor_chats.id`
- `role` enum `chat_role`
- `content` text not null
- `metadata` jsonb nullable
- `created_at` timestamptz

**Indexes**
- index on `chat_id`
- index on `created_at`

### `project_recommendations`
Stores project ideas for portfolio growth.

**Columns**
- `id` UUID PK
- `user_id` UUID FK → `users.id`
- `title` varchar not null
- `description` text not null
- `category` varchar nullable
- `difficulty` enum `difficulty_level`
- `effort_hours` integer nullable
- `impact_score` integer not null
- `skills` jsonb nullable
- `reason` text nullable
- `is_saved` boolean default false
- `is_dismissed` boolean default false
- `created_at` timestamptz

**Indexes**
- index on `user_id`
- index on `impact_score desc`

## Optional Support Tables
- `refresh_tokens` for secure session rotation.
- `notification_preferences` for user-level notification settings.
- `analysis_jobs` for async processing and retries.
- `audit_logs` for security and observability.

## Relationship Summary
- `users` 1 → 1 `github_profiles`
- `users` 1 → many `repositories`
- `users` 1 → many `developer_scores`
- `users` many → many `skills` via `user_skills`
- `users` 1 → many `skill_gaps`
- `users` 1 → many `roadmaps`
- `roadmaps` 1 → many `roadmap_milestones`
- `users` 1 → many `recommendations`
- `users` 1 → many `mentor_chats`
- `mentor_chats` 1 → many `mentor_messages`
- `users` 1 → many `project_recommendations`

## Data Retention Notes
- Keep historical score snapshots for trend analysis.
- Keep chat history unless user deletes it.
- Retain only the most recent sync payloads where storage cost matters.
- Use soft delete for user-visible content that may need recovery.
