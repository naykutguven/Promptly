# Promptly — Quiet Native exploration

Approved by the user on 2026-10-31. This is the selected Quiet Native visual baseline for Library and reader, with native adoption pending. The durable approval record is Docs/QuietNativeDesign.md, including dated frozen images and the separately versioned ReaderHeader. Preserve earlier Native mockups and the Preparation explorations project as historical references. Approval does not request app implementation or further design generation.

## Product and jobs

Promptly is a private offline native macOS 26+ teleprompter. Library is for preparing plain-text scripts and paragraph-boundary sections; the reader is a compact nonactivating notch-anchored or detached reading overlay. No accounts, network, cloud sync, remote AI, analytics, rich-text toolbar, or import onboarding. All copy and sample content in this exploration is synthetic.

## Shared visual language

- Native macOS restraint, not a website, marketing page or dashboard. System font stack: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif. No downloaded display fonts.
- Light surfaces: editor #FFFFFF, sidebar/toolbar #F5F5F7, subtle hover #ECECEF, primary ink #242428, secondary ink #72727C, hairline #E2E2E7. Dark reader: surface #202023, elevated/hover #2D2D32, primary ink #F5F5F7, secondary ink/icons #ADAEB8, hairline #38383F. Accent token --accent defaults to #356CB6; use it for primary actions, focus and pin indicators so pins follow a future accent preference. Pale-blue selection #E7EFFB with ink #28558F. Red #D85B5B only for destructive actions; traffic lights use native red/yellow/green.
- Theme roles correspond across light and dark; reader stays intentionally charcoal for contrast around the camera. Secondary controls are muted and never compete with script text.
- Type roles: toolbar/row labels 13px medium; metadata 11–12px regular; panel headings 13px semibold; document title 27px semibold; editor 18px regular with 1.8 line height; reader title 13px medium; reader body 28px regular/medium with 1.55 line height. Reader font must remain larger than editor font. Sentence-case labels, no uppercase eyebrow headings or prominent repeated Promptly wordmark.
- Spacing rhythm 4/8/12/16/24/32/48px. Shared icon stroke weight around 1.5px with small 14–16px glyphs and comfortable 30–32px hit areas. Hover rounded rect 6px, focus ring 2px with offset; no decorative glass, gradients, fake texture or pill controls everywhere.
- Modest window corners: Library 12px; detached reader 14px; anchored reader top corners zero, lower corners 16px. Very subtle native edge and soft shadow; no chunky capsules. Button radius 6px. Control row uses consistent 16px insets; reader text inset 24px.

## Library target states

Use the approved structure and interaction contract from Docs/LibraryDesign.md as hard product constraints, with only visual harmonization. Active: three columns approximately 212px sidebar, flexible editor, 176px Sections inspector; native window traffic lights and one 56–60px quiet toolbar. No repeated app name, page name or YOUR SCRIPT label in toolbar. Sidebar heading Library and compose icon, search, Pinned above Recently used, subtle blue selected row and small pin indicator. Editor contains document title, honest Saved on this Mac metadata and Edits since last send only for the already-sent active sample; generous plain-text paragraph spacing. Inspector has Sections, quiet count and add; current section gets a subtle blue background with no extra leading marker. One Send to Prompter button with ⌘↵ in its usual trailing toolbar position. No editor footer. No permanent edit/delete buttons on section rows.

Empty: same toolbar and sidebar, disabled search, No scripts yet., no group headings/count, hidden Sections and disabled inspector toggle and Send. Main area a quiet document icon, Your next idea starts here, Create a script to start preparing., and one Create a Script · ⌘N action. No save metadata without document.

## Reader target states

Detached: compact charcoal native overlay. Quiet header with the selected script title A small beginning aligned left; small Collapse, Lock Position, Return to Notch and Hide icons aligned right in muted tone. No Promptly branding or SAMPLE SCRIPT eyebrow; script text is the hero. Keep large high-contrast type and show enough height for full sample lines, no clipped mid-glyph last line. No play/progress/speed/count-in controls: playback is outside current design scope.

Anchored: same colors, title, icons, type roles and insets, but square top corners meeting the screen edge and a noninteractive notch-safe blank strip above controls. Show it against a minimal display-top fragment, with a centered camera/notch area and no interactive control inside the cutout. Allow appropriately wider reader than detached sample. Detached panel retains native resize affordance, anchored one does not need it.

## Sample content shared across surfaces

Document title: A small beginning.
Opening: Every good idea starts with a little room to breathe.
Next paragraph: Before we rush into what comes next, I want to take a moment to look at what is already here. The small things we notice. The questions we keep coming back to.
Sections: Opening, The idea, What comes next.
Sidebar synthetic titles: A warm welcome (pinned), A small beginning (selected), The week ahead, A few closing thoughts.

## Review packaging

The approved package contains four editable HTML artboards: Library · Active; Library · Empty; Reader · Detached; Reader · Anchored, plus a coordinated overview. Review labels/canvas annotations sit outside product windows and are not shipping UI. Frozen snapshots and versions are recorded in Docs/QuietNativeDesign.md. Preserve this approved package; no further generation is requested. It establishes a visual target rather than a claim to reproduce the currently implemented app.

## Accessibility and scope

Keep contrast, meaningful control titles, keyboard focus and generous targets. Allow normal reflow and use static quiet states; no autoplay or decorative movement. Browser concepts do not validate native accessibility, trackpad behavior, physical notch behavior or capture exclusion. Native controls remain the eventual implementation requirement. No new dependencies, capabilities or persistent script data are authorized by this design exploration.

## Selected refinements — 2026-10-30

- Use actual SF Symbols throughout Library and Reader, including contextual and swipe actions. Superdesign embeds static monochrome renders exported directly from AppKit system symbols, tinted with currentColor. Native implementation should use the named SF Symbols so native symbol effects remain available; exported browser artwork does not itself implement those effects. Do not substitute Lucide or other icon families.
- Library symbols: sidebar.left, sidebar.right, square.and.pencil, magnifyingglass, pin.fill, checkmark.circle, plus, doc.text. Pinned-row indicator is pin.fill in var(--accent), currently blue, not a fixed amber color.
- Swipe and context action symbols: Duplicate doc.on.doc; Delete trash; Pin pin.fill; Unpin pin.slash. Preserve neutral Duplicate, destructive red Delete, and accent-colored Pin/Unpin.
- Reader symbols: chevron.up / chevron.down; lock.open / lock.fill; arrow.up.left.and.arrow.down.right for Detach; arrow.up.to.line for Return to Notch; xmark for Hide; arrow.down.right for the existing diagonal resize cue. Use regular-weight 14px visible control glyphs inside the existing 32px targets. The decorative resize cue remains 12px with equal 12px edge insets.
- Section order numbers inherit the same system font family and proportional digit treatment as other interface numbers. No font-mono, code-style font, or tabular numerals for these labels.
- Resize cue uses tight visible symbol bounds, a block display with no baseline/padding offset, and exactly 12px trailing and bottom insets. Preserve reader content, window dimensions and other layout.
