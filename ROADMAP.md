# Holdco Roadmap

Holdco is becoming the system of record for multi-entity finance operations:
structure, books, close, reconciliation, reporting, and control.

This roadmap is intentionally not date-based. It is ordered by product and
engineering priority.

## Positioning

Holdco should be strongest where operators need trust, control, and visibility:

- entity structure and ownership
- accounting and journal workflows
- reconciliation and close
- consolidated reporting
- auditability and approvals

It should not optimize first for breadth, novelty, or platform surface area.

## Product Wedge

The core wedge is:

`multi-entity monthly close + consolidated reporting + auditability`

That is the workflow most likely to create recurring operational value.

## Strategic Principles

Use these as filters for roadmap decisions:

- Trust before intelligence
- Workflow before feature count
- Exceptions before dashboards
- Consolidation before expansion
- AI as an accelerator, not an authority
- Integrations must be observable, not just connected

## What Already Works

Before building new, acknowledge what is load-bearing today:

- **Double-entry accounting** with chart of accounts, journal entries, and
  journal lines. Period locks enforced at write-time (journal creation returns
  `:period_locked` if the date falls in a locked period).
- **Bank reconciliation engine** with scoring (amount 50pts, date proximity
  30pts, description similarity 20pts), auto-match at threshold 60, manual
  match, candidates list, and double-match prevention.
- **Period close checklist** showing per-entity reconciliation status, journal
  entry count, and lock status. One-click lock from the checklist. Defaults to
  previous calendar month. Subscribes to PubSub for live updates.
- **Consolidated financials** with intercompany elimination and non-controlling
  interest for both balance sheet and income statement.
- **Financial reports**: trial balance, balance sheet, income statement with
  per-company and date-range filtering.
- **Dashboard** with NAV, returns, period comparison, financial ratios, 90-day
  cash forecast, entity performance, asset allocation, action items strip
  (unreconciled items, open periods, due recurring transactions, pending
  approvals), audit feed, and AI insights.
- **QuickBooks and Xero integrations** with OAuth2, token refresh, and
  bidirectional sync of accounts and journal entries.
- **AI layer** with Anthropic/OpenAI integration, portfolio-aware context
  building, conversation history, and floating chat panel.

## What To Build Next

### 1. Monthly Close Workflow

Status: entity-level checklist exists but does not enforce blockers or support
group-level close.

Objective: make close the core operational loop that everything else feeds into.

Priority work:

- Add close blockers that prevent locking: unreconciled bank items, draft
  journals, pending approvals, missing tax inputs. The current checklist shows
  status but does not gate the lock action.
- Add group-level close on top of entity-level close: a group cannot close
  until all member entities are closed.
- Add close activity history and per-period notes so operators can see who
  closed what and when.
- Surface "what is blocking close?" from the dashboard action items strip and
  from the period close page.
- Make period locks, approvals, and exports part of one coherent close flow.

Done when:

- locking an entity is gated by reconciliation and journal completeness
- operators can close a group after all entities are closed
- close status and blockers are visible from the dashboard without navigating
  to the close page

### 2. Multi-Currency Consolidation

Status: consolidation sums raw numbers across entities with no FX handling.
The dashboard supports a currency selector with FX conversion, but the
consolidation module does not.

Objective: make consolidated financials correct when entities report in
different currencies.

Priority work:

- Add reporting currency to the consolidation flow. Each entity has a
  functional currency; consolidation converts to a single reporting currency.
- Implement translation adjustments: balance sheet items at closing rate,
  income statement items at average rate, equity at historical rate.
- Surface FX gains/losses from translation as a separate line item in
  consolidated equity (cumulative translation adjustment).
- Warn when FX rates are missing or stale for any entity in the consolidation.
- Add tests that consolidate entities in different currencies and verify the
  math against known examples.

Done when:

- consolidated reports produce correct numbers when entities use different
  currencies
- translation adjustments are visible and auditable
- missing or stale FX rates block or warn rather than silently producing
  wrong numbers

### 3. Trusted Financial Core

Objective: make all core financial outputs defensible and explainable.

Priority work:

- Define canonical rules for NAV, gains, liabilities, snapshots, and
  consolidated balances.
- Tighten source-of-truth ownership for transactional data, snapshot data, and
  derived metrics.
- Surface stale prices, missing FX, duplicate transactions, and incomplete
  classifications instead of silently masking them.
- Expand financial correctness tests around consolidated totals, close-period
  behavior, and export consistency.
- Add metric provenance and operator-visible data quality warnings.

Done when:

- top-level financial metrics have explicit provenance
- exports and dashboards reconcile to the same definitions
- critical totals fail loudly when inputs are missing or stale

### 4. Reconciliation and Ingestion Reliability

Status: scoring engine, auto-match, manual match, and candidates work.
Statement CSV import has deduplication via external_id. QuickBooks and Xero
sync are functional but lack health visibility and systematic idempotency.

Objective: make external data dependable enough for recurring use.

Priority work:

- Make all sync paths idempotent: re-running a bank CSV import or a QB/Xero
  sync must not create duplicates. Enforce external_id uniqueness at the
  database level where it is not already enforced.
- Add sync health visibility: last success, last failure, retry state, and
  data freshness per integration, visible from both the integrations page and
  the dashboard.
- Build an exception queue for low-confidence reconciliation matches (score
  between 40-60) instead of silently dropping them.
- Add stale integration and sync failure alerts.

Done when:

- operators can see what synced, what failed, and what needs review
- re-importing or re-syncing never creates duplicates
- low-confidence matches surface for manual review instead of being invisible

### 5. Operator UX Simplification

Objective: reduce cognitive load without reducing capability.

Priority work:

- Rework the dashboard into an action center for close, exceptions, and
  pending work. The dashboard already has an action items strip; make it the
  primary entry point rather than the metrics.
- Simplify company operations into clearer task-based flows.
- Split overloaded screens into smaller operator workflows where needed.
- Defer non-critical data on page load and precompute expensive aggregates.
- Make permissions, approval state, and editability obvious in the interface.

Done when:

- the main workflows are clear to a new operator
- key tasks take fewer steps and less context-switching
- the product feels operational rather than encyclopedic

### 6. Intelligence Layer

Objective: use AI and analytics to accelerate operators after the data and
workflow foundation is strong.

Priority work:

- Explain changes in NAV, cash movement, entity performance, and anomalies.
- Draft report commentary and management summaries from grounded data.
- Help operators triage anomalies and exception queues.
- Improve search and question-answering against real portfolio context.
- Show the context or source behind AI-generated output where practical.

Done when:

- AI usage is attached to real workflows, not novelty interactions
- the product remains fully useful without AI enabled
- generated output improves speed without weakening trust

### 7. Tax Into Close

Objective: tie tax workflows directly into the close loop.

Priority work:

- Make tax deadline completion a close blocker where configured.
- Surface outstanding tax obligations in the close checklist.
- Include tax provisions in consolidated reporting.
- Improve audit packages and stakeholder-ready reporting.

Do later:

- compliance deadlines as generic calendar items
- white-labeling
- broad plugin/platform work
- feature expansion that does not strengthen close, reporting, or controls

## What Not To Prioritize Yet

- net-new feature categories for their own sake
- AI-first experiences that bypass operator review
- broad platformization and marketplace work
- wide customization layers before core workflows are excellent
- peripheral modules that do not improve close, reconciliation, reporting, or
  auditability
- schemas and contexts without UI workflows (Collaboration, parts of
  Governance, parts of Compliance) — these exist in the codebase but should not
  drive roadmap decisions until the core loop is excellent

## Operating KPIs

Track progress with outcome metrics, not only feature delivery:

- time to close per entity
- number of blocked closes and blocker types
- unreconciled transaction count
- sync success and failure rate by integration
- stale pricing and FX input count
- export and report generation success rate
- median page load time for dashboard and company workflows
- percentage of AI interactions attached to core workflows
- financial output error rate (incorrect reports, mismatched exports)

## Short Version

Holdco is focused first on monthly close (with blockers and group-level
close), multi-currency consolidation, trusted numbers, reconciliation
reliability, and auditability. AI, tax, compliance, and integrations matter,
but they should strengthen the core operating workflow rather than pull the
product in unrelated directions.
