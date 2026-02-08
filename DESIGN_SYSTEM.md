# OperatorKit Design System v2.0

## Trust-First Interface

**Design Philosophy:** Apple × Palantir × Linear

OperatorKit is infrastructure, not entertainment. The interface signals control, safety, intelligence, and precision.

---

## Color Tokens

### Backgrounds

| Token | Hex | Usage |
|-------|-----|-------|
| `bg-primary` | `#FFFFFF` | Main screen background |
| `bg-secondary` | `#F7F8FA` | Card backgrounds, subtle surfaces |
| `bg-tertiary` | `#F1F5F9` | Input field background |
| `bg-elevated` | `#FFFFFF` | Floating cards, modals |

### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | `#0B0B0C` | Headlines, body text |
| `text-secondary` | `#6B7280` | Secondary labels, descriptions |
| `text-tertiary` | `#94A3B8` | Timestamps, metadata |
| `text-placeholder` | `#94A3B8` | Input placeholders |

### Borders & Dividers

| Token | Hex | Usage |
|-------|-----|-------|
| `border-subtle` | `#E6E8EC` | Card borders, dividers |
| `border-default` | `#E2E8F0` | Input borders |
| `border-focus` | `#5B8CFF` | Focus states |

### Operator Gradient (Accent)

| Token | Value | Usage |
|-------|-------|-------|
| `accent-start` | `#5B8CFF` | Gradient start |
| `accent-end` | `#7C5CFF` | Gradient end |
| `accent-muted` | `rgba(91, 140, 255, 0.08)` | Background tints |
| `accent-glow` | `rgba(91, 140, 255, 0.15)` | Glow effects |

**Usage Rules:**
- Apply gradient ONLY for action moments
- Microphone button, primary CTAs, approval states
- Never flood the screen
- Restraint signals confidence

### Icons

| Token | Hex | Usage |
|-------|-----|-------|
| `icon-primary` | `#6B7280` | Card icons, action icons |
| `icon-secondary` | `#9AA0A6` | Settings, navigation |
| `icon-muted` | `#B8BCC4` | Disabled states |

---

## Typography Scale

**Font:** SF Pro (system font)

| Style | Size | Weight | Line Height | Letter Spacing |
|-------|------|--------|-------------|----------------|
| Large Title | 28px | Semibold (600) | 34px | -0.4px |
| Title | 22px | Semibold (600) | 28px | -0.3px |
| Headline | 17px | Semibold (600) | 22px | -0.2px |
| Body | 16px | Regular (400) | 22px | -0.1px |
| Callout | 15px | Regular (400) | 20px | 0 |
| Subheadline | 14px | Medium (500) | 18px | 0 |
| Footnote | 13px | Regular (400) | 18px | 0 |
| Caption | 12px | Medium (500) | 16px | 0.1px |

---

## Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Tight gaps, inline spacing |
| `sm` | 8px | Icon-text gaps |
| `md` | 12px | Card internal padding |
| `lg` | 16px | Section spacing |
| `xl` | 20px | Screen margins |
| `xxl` | 24px | Section breaks |
| `xxxl` | 32px | Major sections |

---

## Radius Scale

| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 8px | Small buttons, tags |
| `md` | 12px | Icons, small cards |
| `lg` | 16px | Input fields |
| `xl` | 20px | Cards, modals |
| `full` | 9999px | Circular buttons |

---

## Shadows

| Token | Value | Usage |
|-------|-------|-------|
| `subtle` | `0 1px 2px rgba(0,0,0,0.03)` | Subtle elevation |
| `card` | `0 2px 8px rgba(0,0,0,0.04)` | Cards at rest |
| `elevated` | `0 4px 16px rgba(0,0,0,0.06)` | Hover states, modals |
| `glow` | `0 0 24px rgba(91,140,255,0.12)` | Mic button, action states |

---

## Component Specifications

### Input Field

```
Background: #F1F5F9
Text: #0B0B0C
Placeholder: #94A3B8
Border: 1px #E2E8F0
Border Radius: 16px
Padding: 16px
Focus Border: #5B8CFF
Focus Shadow: 0 0 0 3px rgba(91,140,255,0.08)
```

### Operation Card

```
Background: #FFFFFF
Border: 1px #E6E8EC
Border Radius: 20px
Padding: 16px
Shadow: 0 2px 8px rgba(0,0,0,0.04)
Hover Shadow: 0 4px 16px rgba(0,0,0,0.06)
Hover Transform: translateY(-1px)
```

### Card Icon

```
Size: 36px × 36px
Background: #F7F8FA
Border Radius: 12px
Icon Size: 18px
Icon Color: #6B7280
```

### Floating Microphone Button

```
Size: 72px × 72px
Shape: Circle
Background: linear-gradient(135deg, rgba(91,140,255,0.12), rgba(124,92,255,0.12))
Shadow: 0 0 24px rgba(91,140,255,0.12)
Glow Layer: radial-gradient(circle, rgba(91,140,255,0.15) 0%, transparent 70%)
Glow Size: 96px × 96px
Icon Size: 28px
```

### Settings Icon

```
Size: 22px × 22px
Color: #9AA0A6
Container: 40px × 40px
Container Radius: 12px
Hover Background: #F7F8FA
```

---

## Interaction States

### Buttons

| State | Change |
|-------|--------|
| Default | Base styling |
| Hover | Background lightens, subtle lift |
| Active | Scale 0.98, shadow reduces |
| Disabled | 50% opacity, no interaction |

### Cards

| State | Change |
|-------|--------|
| Default | Base shadow |
| Hover | Elevated shadow, -1px Y translate |
| Active | Slight scale reduction |

### Inputs

| State | Change |
|-------|--------|
| Default | Subtle border |
| Focus | Accent border, glow ring |
| Error | Red border, red glow |

---

## Animation Guidelines

| Property | Duration | Easing |
|----------|----------|--------|
| Hover transforms | 200ms | ease-out |
| Focus states | 150ms | ease-in-out |
| Page transitions | 300ms | ease-in-out |
| Micro-interactions | 100ms | ease-out |

### Glow Pulse Animation

```css
@keyframes pulse {
  0%, 100% {
    opacity: 0.6;
    transform: scale(1);
  }
  50% {
    opacity: 1;
    transform: scale(1.05);
  }
}
duration: 3s
timing: ease-in-out
iteration: infinite
```

---

## Accessibility

- Minimum contrast ratio: 4.5:1 for text
- Touch targets: 44px minimum
- Focus indicators: visible on all interactive elements
- Motion: respect `prefers-reduced-motion`

---

## Files

| File | Purpose |
|------|---------|
| `OperatorKit-DesignSystem.jsx` | React component + tokens |
| `OperatorKit-UI-Redesign.html` | Interactive HTML mock |
| `DESIGN_SYSTEM.md` | This documentation |

---

*OperatorKit Design System v2.0 — Trust-First Interface*
