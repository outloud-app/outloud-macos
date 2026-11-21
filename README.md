# Outloud

Native macOS marketing research and drafting workspace, with a FastAPI backend foundation.

## This build

- Neutral near-black SwiftUI interface, mint accents, slim icon rail and contextual sidebar.
- Distinct global Home, Projects, Search and Settings controls; project-specific navigation stays in the contextual sidebar.
- Bundled Reddit, Instagram, X and TikTok vector marks.
- Bundled Inter variable font (SIL Open Font License, included in outloud/Resources/Fonts/).
- Projects, project accent colors, topic/account watchlists and manual reference imports.
- Discover platform/category/search filters, reference detail, saved references and example conversations.
- Studio cover previews, in-workspace editors, manual text editing, copy and plain-text export.
- Basic image draft layout with editable headline, project colors and 1080 × 1080 PNG export.
- Workspace persistence on this Mac with atomic writes and corrupt-file preservation.
- Separate development API for persistent projects and versioned drafts.

The app persists projects, references and drafts locally. Native ResearchClient connects to the shared research backend using a license-authorized device session. Debug builds point to http://127.0.0.1:8766; Release requires OUTLOUD_RESEARCH_SERVER_URL to be set to a deployed HTTPS service. A configured client does not by itself validate live research coverage.

Startup opens a project chooser. File → New Project and Close Project manage navigation. Product briefs require comma-separated research keywords (maximum 100 characters, including commas) for both launched and unlaunched apps, with or without a public link. Competitor names or links remain optional, with no three-item cap. Product details updates the brief and prepares fresh research without deleting saved references. Public metadata can populate product descriptions.

Generation, video rendering, automatic watchlist monitoring and App Store Connect/Google Play account connections remain unimplemented. Manual text and basic image export are available. The historical public 0.1.4 DMG is a different release from this developing workspace; do not replace or publish release downloads until the native workspace has been verified end to end.

## Run the Mac app

Open outloud.xcodeproj, select the outloud scheme and My Mac, then Run.
The existing project targets macOS 27 and retains the original bundle identifier and signing team.

Command-line build when the selected system toolchain is Command Line Tools:

    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
      xcodebuild -project outloud.xcodeproj -scheme outloud \
      -configuration Debug -derivedDataPath /tmp/outloud-build \
      CODE_SIGNING_ALLOWED=NO build

Unsigned builds are for local verification. Distribution signing and notarization are later release tasks.

Workspace data: Application Support/Outloud/workspace-v1.json inside the app's container when sandboxed. Draft changes save locally as you edit. The app currently uses one workspace window to avoid competing independent in-memory stores.

## Run the development API

Backend: `/Users/apple/VSCodeProjects/outloud-backend`

From that folder:

    python3 -m venv .venv
    .venv/bin/python -m pip install -r requirements-lock.txt
    export OUTLOUD_DEV_TOKEN="$(.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')"
    .venv/bin/python -m uvicorn outloud_api.main:create_app --factory --host 127.0.0.1 --port 8000

Use the bearer token in the interactive API docs at http://127.0.0.1:8000/docs. Do not put the token in source control.

This API intentionally serves **one local development workspace**. Its development bearer token is not production user authentication. Keep it bound to loopback; add cloud identity and ownership enforcement before hosting publicly. SQLite is for local iteration; the SQLAlchemy model layer can target PostgreSQL after driver/configuration and Alembic migrations are added. Automatic table creation is temporary development bootstrap, not a migration strategy.

Endpoints:

- GET /health
- GET /v1/capabilities
- GET, POST /v1/projects
- GET /v1/projects/{project_id}
- GET, POST /v1/projects/{project_id}/drafts
- PUT /v1/drafts/{draft_id} — requires expected_revision; stale writes return 409.
- DELETE /v1/drafts/{draft_id}

## Verification

Backend:

    cd /Users/apple/VSCodeProjects/outloud-backend
    .venv/bin/python -m pytest -q

Native workspace behavior, from the repository root:

    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
      -parse-as-library outloud/DesignSystem.swift outloud/WorkspaceModels.swift \
      outloud/WorkspaceStore.swift scripts/WorkspaceChecks.swift \
      -o /tmp/outloud-workspace-checks
    /tmp/outloud-workspace-checks

The checks use temporary storage, not the real workspace. They cover project separation, reference import/save, drafts, watchlists, persistence across store recreation, deletion and unreadable-file preservation.

Debug-only app-view captures:

    OUTLOUD_PREVIEW_PATH=/tmp/outloud-discover.png \
      /tmp/outloud-build/Build/Products/Debug/outloud.app/Contents/MacOS/outloud

Set OUTLOUD_PREVIEW_PAGE to discover, conversations, reference, studio or editor. The editor preview opens a sample image draft inside the workspace. Captures use an in-memory workspace and only the app's own content view. The process exits after writing the PNG. Updated captures are in docs/previews/ with the -v2 suffix.

Verified for this initial slice: macOS Debug build succeeds; native workspace behavior checks pass; all 7 API tests pass. The current Starlette test client reports a deprecation warning for httpx, which does not affect these results. Discover, Studio and editor views were rendered for visual inspection.

## Next implementation milestones

1. Validate one permitted, affordable discovery source with real niche searches and a documented refresh budget.
2. Select cloud identity, add server ownership checks and connect the Mac client's projects/drafts using the versioned API contract.
3. Add ingestion/provenance, reference analysis and actual conversation data.
4. Add generation quotes, a durable worker, credit reservations and one text/image provider.
5. Implement Stripe subscription/top-up flows and webhook reconciliation.
6. Add media editing/export, paid-beta checks, landing page and signed/notarized distribution.

## Marketing website

The separate Next.js + Tailwind website is in /Users/apple/VSCodeProjects/outloud-website.
Public waitlist: https://tryoutloud.pages.dev/.

### Running locally in Xcode

Run the `outloud` scheme with the Debug configuration (⌘R). It opens the project chooser without a paid license. Sparkle is completely disabled in Debug, so a local build cannot install an older published app over itself. To test activation deliberately, add `OUTLOUD_TEST_LICENSING=1` to the scheme’s Run environment. Release builds always require activation.

Local research uses the loopback service on port 8766. Start it from `/Users/apple/VSCodeProjects/outloud-backend` with `.venv/bin/python scripts/research/serve-local.py`. Its developer access works only when explicitly enabled on loopback, and never grants a production license. This launcher keeps paid collection disabled and reuses available research.

Home, Discover and Conversations follow the supplied HTML prototype: topic filters, media reference cards, evidence-based feed summaries, and a conversation list with a selected discussion. Topic seeds are sent separately from confirmed product features and inform retrieval and local profile matching. Conversation lead/dismiss decisions persist across refreshes. Replies and unsupported performance statistics are not fabricated.

Product descriptions support 30–1,200 characters in setup, About, metadata imports and research requests. Both link and description setup routes include an optional competitor step. About is available directly in the sidebar, with Overview, Research and Appearance sections, a logo-based platform picker and an expandable description editor.

Recent projects support a native context menu and hover trash action. Deletion requires the exact project name and removes associated local references, saves, drafts and sources. Projects open on Home. Sources appear immediately in the sidebar; public social-profile metadata is used for profile images when available, with a fallback when a site restricts access.

Studio animation plays once per visit. About Save is enabled only after editable fields change; unchanged legacy profile fields do not prevent local appearance edits. Edit keywords opens the Research section and focuses/highlights the keyword field. Image import failures use a translucent, system-appearance-aware warning; uploaded icons must be square and under 10 MB. Strong horizontal trackpad swipes expand the delete capsule and request confirmation; deletion still requires typing the exact project name.

Window navigation uses live destination layouts with a continuous native backing surface: resize first, then reveal fully laid-out content. Launcher/workspace bitmap covers are not used. Close Project is a no-op on the launcher and also dismisses an active setup flow. Motion diagnostics exercise both system appearances and repeated close commands in addition to launcher/setup/workspace routes.
