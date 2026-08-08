---
name: test-write
description: Write a new test case document and/or XCUITest automation script for a specific Oura Studios feature or user flow. Use this skill whenever the user asks to document a test scenario, create automation for a flow, or add a test case to the test library. Trigger phrases: "buatkan test case", "tambah test", "buat automation untuk", "dokumentasikan test", "script test untuk". Always run test-smoke first if the app hasn't been verified to build yet.
---

# Oura Studios — Test Writer

This skill creates two artifacts per test case: a **scenario document** (in `test/docs/`) and an **automation script** (in `test/scripts/`). The script filename must appear in the doc so they can be found from each other.

---

## Folder structure (canonical)

```
test/
├── docs/
│   └── TC-{NNN}-{kebab-case-title}.md     ← scenario doc
└── scripts/
    └── TC{NNN}_{PascalCaseTitle}.swift     ← XCUITest script
```

**ID assignment:** look at existing files in `test/docs/` and increment the highest TC-NNN by 1. If none exist, start at TC-001.

**Linking rule:** the doc must contain a line like:
```
**Script:** `test/scripts/TC{NNN}_{PascalCaseTitle}.swift`
```
The script must start with a comment:
```swift
// Doc: test/docs/TC-{NNN}-{kebab-case-title}.md
```

---

## Part 1 — Scenario document format

```markdown
# TC-{NNN} — {Short Title}

| Field | Value |
|---|---|
| **ID** | TC-{NNN} |
| **Feature** | {Screen or module name} |
| **Type** | Positive / Negative / Edge case |
| **Priority** | P1 / P2 / P3 |
| **Script** | `test/scripts/TC{NNN}_{PascalCaseTitle}.swift` |
| **Added** | {YYYY-MM-DD} |

## Preconditions

- {List prerequisites: app state, seed data, user must be authenticated, etc.}

## Steps

| Step | Action | Element / Identifier |
|---|---|---|
| 1 | Navigate to … | Tab bar → "Produksi" |
| 2 | Tap … | `app.buttons["…"]` |
| … | … | … |

## Expected Results

| # | Expected | How to verify |
|---|---|---|
| 1 | Sheet dismisses | `XCTAssertFalse(sheet.exists)` |
| 2 | Item appears in list | `app.staticTexts["…"].waitForExistence` |
| … | … | … |

## Notes

- {Any quirks, known flakiness, dependencies on other TCs}
```

**Priority guide:**
- **P1** — core create/save flow; app is unusable without it
- **P2** — important validation, error state, or list update
- **P3** — edge case, optional field behavior, cosmetic

---

## Part 2 — XCUITest script conventions

### Project setup

Scripts live in `test/scripts/` as standalone `.swift` files. To run them, add the file to the **`oura studio frontendUITests`** Xcode target (Target Membership checkbox in File Inspector). The `oura_studio_frontendUITests.swift` file already sets up the test class and helpers — new test cases should be added as extensions in their own files, not appended to the base file.

Template for a new script file:

```swift
// Doc: test/docs/TC-{NNN}-{kebab-case-title}.md
import XCTest

extension oura_studio_frontendUITests {

    // MARK: - TC-{NNN} {Short Title}

    @MainActor
    func testTC{NNN}_{PascalCaseTitle}() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-bypass-auth"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8),
                      "Tab bar harus muncul setelah launch")

        // … steps …
    }
}
```

### Known identifier patterns (derived from component source)

| Component | How to find it | Example |
|---|---|---|
| `SearchableDropdownField` open button | `.accessibilityIdentifier("dropdown-{label}")` | `app.buttons["dropdown-Bahan"]` |
| Items inside SearchableDropdownField sheet | `.accessibilityIdentifier("item-{name}")` | `app.buttons["item-Satin Pelangi"]` |
| `InlineSearchDropdownField` text field | `.accessibilityIdentifier("inline-search-{label}")` | `app.textFields["inline-search-Produk"]` |
| Items inside InlineSearchDropdownField | `.accessibilityIdentifier("item-{name}")` | `app.buttons["item-Scrunchie"]` |
| `TokenizedMultiSelectField` open button | `.accessibilityIdentifier("tokenized-field-{label}")` | `app.buttons["tokenized-field-Kain yang Digunakan"]` |
| Items inside tokenized select sheet | `.accessibilityIdentifier("item-{name}")` | `app.buttons["item-Silk Putih"]` |
| `NumericInputField` text field | `.accessibilityLabel("{label}")` | `app.textFields["Panjang (cm)"]` |
| `CurrencyInputField` text field | `.accessibilityLabel("Total Biaya")` | `app.textFields["Total Biaya"]` |
| Nav bar "Simpan" button | `app.navigationBars.buttons["Simpan"]` | — |
| Nav bar "Batal" button | `app.navigationBars.buttons["Batal"]` | — |
| Tab bar tabs | `app.tabBars.buttons["{label}"]` | `app.tabBars.buttons["Produksi"]` |
| Produksi inner sub-tabs | `app.buttons["{label}"]` | `app.buttons["Bahan"]` |
| "+" FAB / add button | `app.buttons["Tambah Pembelian"]` (use button label if set) | — |

### Required helper methods (already in `oura_studio_frontendUITests.swift`)

- `screenshot(app, name:)` — attaches a screenshot as XCTAttachment (`.keepAlways`)
- `tapDone(app)` — dismisses keyboard if "Done" button exists (use before tapping items near keyboard)
- `tapCell(in:text:timeout:)` — tries `item-{text}` button first, falls back to List cell. **Use this for all item selections** instead of direct `.tap()` — handles iOS 26 hittability quirks.

### Anti-patterns to avoid

- **Don't use `.firstMatch` on text** unless the text is guaranteed unique. Prefer specific identifiers.
- **Don't hardcode `sleep(n)`** — use `waitForExistence(timeout:)` or `XCTNSPredicateExpectation`.
- **Don't skip screenshots** for steps that change state — `screenshot(app, name:)` is cheap and critical for diagnosing failures in CI.
- **Don't use force unwrap** (`XCUIElement!`) — always assert existence before tapping.

---

## Part 3 — Test case naming and classification

| Suffix in title | Meaning |
|---|---|
| `- Positive Case` | Happy path, all fields valid, expects success |
| `- Negative Case` | Invalid input or blocked action, expects error/rejection |
| `- Edge Case` | Boundary value, empty state, or unusual-but-valid scenario |

Positive cases always come first (TC-NNN). Negative cases for the same feature get the next ID(s).

---

## When you're done

1. Verify both files exist in `test/docs/` and `test/scripts/`.
2. Confirm the `**Script:**` link in the doc matches the actual filename.
3. Confirm the `// Doc:` comment at the top of the script matches the actual doc filename.
4. If the test script references an accessibility identifier that doesn't yet exist in the SwiftUI source, add a `// TODO(accessibility):` comment in the script at that line, and note it in the doc's Notes section so the developer knows to add it.
