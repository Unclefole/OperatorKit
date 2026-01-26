# WEBSITE SECURITY PROOF COPY

**Document Type**: Marketing/Website Copy  
**Audience**: Marketing, Website, Landing Pages  
**Phase**: L3

---

## Guidelines

- Factual, not hyperbolic
- No absolute guarantees ("guaranteed", "unhackable", "bulletproof")
- Reference verifiable artifacts
- Use "designed to" language

---

## Copy Block 1: How We Prove Zero-Network

### Headline

**Your data never phones home. Here's the proof.**

### Body

OperatorKit's core processing pipeline—from your intent to the final draft—operates entirely on your device. No cloud servers. No API calls. No data leaving your phone.

But don't take our word for it. The app includes built-in verification:

- **Binary inspection** confirms no networking frameworks are linked
- **Symbol analysis** verifies no network APIs exist in the code
- **Entitlements audit** shows no network permissions are requested
- **Offline certification** proves the pipeline works in Airplane Mode

You can export this evidence as a JSON file and verify it yourself using standard iOS development tools.

### CTA

[Learn How to Verify →]

---

## Copy Block 2: Why No WebKit Matters

### Headline

**No browser. No JavaScript. No surprises.**

### Body

Many apps embed web views that can load arbitrary content, execute JavaScript, or connect to remote servers. OperatorKit is different.

We deliberately exclude:

- **WebKit** — The framework that powers Safari and in-app browsers
- **JavaScriptCore** — Apple's JavaScript engine
- **SafariServices** — Safari-based authentication and browsing

This isn't a configuration choice. These frameworks are architecturally absent from the binary. You can verify this yourself by inspecting the app's linked frameworks.

### Technical Note

```bash
# Verify it yourself
otool -L /path/to/OperatorKit.app/OperatorKit | grep -i webkit
# Expected: No results
```

---

## Copy Block 3: What We Log vs. Never Log

### Headline

**Metadata only. Never your words.**

### Body

OperatorKit maintains an audit trail for your peace of mind. Here's exactly what we track:

**What we log (metadata only):**
- Event types (email drafted, calendar created, etc.)
- Timestamps (day-rounded for privacy)
- Action counts
- Policy decisions (approved, rejected)

**What we never log:**
- Email content or subjects
- Calendar event details
- Recipients or attendees
- Your notes or context
- Any free-text you write

The audit trail exists so you can verify what the app did—not to collect your data.

---

## Copy Block 4: Draft-First Architecture

### Headline

**Nothing happens without your approval.**

### Body

OperatorKit follows a "draft-first" model:

1. **You select context** — Choose which emails, events, or notes to include
2. **AI creates a draft** — Processing happens entirely on your device
3. **You review the draft** — See exactly what will be sent or created
4. **You approve explicitly** — Tap to confirm, or edit and try again

There's no "auto-send," no "background processing," no actions taken while you're not looking. Every execution requires your explicit approval.

---

## Copy Block 5: Verifiable, Not Promised

### Headline

**Don't trust. Verify.**

### Body

We don't ask you to trust our security claims. We give you the tools to verify them.

Inside the app:
- **Trust Dashboard** — See real-time proof of security posture
- **Proof Pack Export** — Download a JSON bundle of all evidence
- **Build Seals** — Cryptographic hashes of entitlements and dependencies

Outside the app:
- Use `codesign` to extract entitlements
- Use `nm` and `otool` to inspect the binary
- Run the open-source test suite

Every claim we make is backed by auditable evidence.

---

## Copy Block 6: On-Device AI

### Headline

**AI that never leaves your phone.**

### Body

OperatorKit uses Apple's on-device Foundation Models for all AI processing. Your prompts, your context, and your drafts never leave your device.

This isn't just a privacy feature—it's a fundamental architecture decision. There's no server to hack, no API to intercept, no cloud database storing your data.

The AI runs locally. Period.

---

## Copy Block 7: For the Paranoid (Complimentary)

### Headline

**Built for people who read privacy policies.**

### Body

If you're the kind of person who:
- Reads App Store privacy labels
- Checks network activity with a proxy
- Wants to see the actual binary, not just marketing claims

Then OperatorKit was built for you.

We provide:
- Full binary inspection tools
- Exportable proof artifacts
- Open test suites
- Step-by-step audit guides

Skepticism is healthy. We give you the evidence to satisfy it.

---

## Short-Form Snippets

### For Headers/Banners

- "On-device AI. Zero network calls."
- "Draft-first. Approval-gated. Your control."
- "Verifiable security, not just promises."

### For Feature Lists

- ✓ No WebKit or JavaScript frameworks
- ✓ No background data collection
- ✓ No cloud AI processing
- ✓ Exportable proof artifacts
- ✓ Works in Airplane Mode

### For Social/Ads

- "Your productivity assistant that can't phone home."
- "AI that processes locally. Evidence you can export."
- "Built for people who verify, not just trust."

---

## Forbidden Phrases (Do Not Use)

| Phrase | Reason |
|--------|--------|
| "Guaranteed secure" | Absolute claim |
| "Unhackable" | Impossible to guarantee |
| "Military-grade" | Meaningless marketing |
| "Bank-level security" | Vague comparison |
| "100% safe" | Absolute claim |
| "Bulletproof" | Hyperbolic |
| "Ironclad" | Hyperbolic |
| "Fortress" | Hyperbolic |

---

## Document Metadata

| Field | Value |
|-------|-------|
| Created | Phase L3 |
| Classification | Marketing Copy |
| Runtime Changes | NONE |
