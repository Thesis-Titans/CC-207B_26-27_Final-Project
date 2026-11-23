# AI usage log

Record every use of AI to generate or refactor code, debug, or create sample data, text or images (CC 207B AI Use Policy). Learning concepts, explaining error messages and finding documentation do not need a row. Add your row in the same pull request as the change.

| Member | Date | AI tool | What it was used for / prompt summary | What was generated | What the member changed |
|---|---|---|---|---|---|
| Vincent John Tamaño | 2026-11-20 | Gemini | Sample data: Generate synthetic milestone observation prompts matching 4 ECCD domains for 12-23 months | 4 MilestonePrompt objects with bullet points and non-diagnostic provenance label | Reviewed wording against non-diagnostic requirements and added to milestone.dart |
| Vincent John Tamaño | 2026-11-21 | Gemini | Debugging: Resolve syntax error with enum declaration inside class body in milestone.dart | Placement fix for MilestoneDomain enum and Material icons import | Moved enum to top-level scope and imported flutter/material.dart |
| Vincent John Tamaño | 2026-11-21 | Gemini | Snippet: Automated test assertion snippet to audit milestone titles for banned clinical words | testWidgets loop checking banned words list against sampleMilestonePrompts | Integrated into milestones_screen_test.dart and verified test execution |
| Vincent John Tamaño | 2026-11-23 | Gemini | Sample data: Generate synthetic WeeklySummary fixtures and test assertions for populated/empty weeks (WP-B6 / Issue #8) | Synthetic sampleWeeklySummaries fixture map and widget test scaffold | Built WeeklySummaryScreen UI, Monday-Sunday week picker, domain breakdown, and non-diagnostic reflection cards |
