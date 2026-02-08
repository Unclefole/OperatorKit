import React from 'react';

// ============================================================================
// OPERATORKIT DESIGN SYSTEM v2.0
// Trust-First Interface — Apple × Palantir × Linear
// ============================================================================

// COLOR TOKENS
const colors = {
  // Backgrounds
  background: {
    primary: '#FFFFFF',
    secondary: '#F7F8FA',
    tertiary: '#F1F5F9',
    elevated: '#FFFFFF',
  },

  // Text
  text: {
    primary: '#0B0B0C',
    secondary: '#6B7280',
    tertiary: '#94A3B8',
    placeholder: '#94A3B8',
  },

  // Borders & Dividers
  border: {
    subtle: '#E6E8EC',
    default: '#E2E8F0',
    focus: '#5B8CFF',
  },

  // Operator Gradient (Accent)
  accent: {
    start: '#5B8CFF',
    end: '#7C5CFF',
    muted: 'rgba(91, 140, 255, 0.08)',
    glow: 'rgba(91, 140, 255, 0.15)',
  },

  // Status Colors (Muted)
  status: {
    success: '#6B7280',
    pending: '#6B7280',
    info: '#6B7280',
  },

  // Icons
  icon: {
    primary: '#6B7280',
    secondary: '#9AA0A6',
    muted: '#B8BCC4',
  },
};

// TYPOGRAPHY SCALE
const typography = {
  largeTitle: {
    fontFamily: 'SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 28,
    fontWeight: '600',
    lineHeight: 34,
    letterSpacing: -0.4,
  },
  title: {
    fontFamily: 'SF Pro Display, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 22,
    fontWeight: '600',
    lineHeight: 28,
    letterSpacing: -0.3,
  },
  headline: {
    fontFamily: 'SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 17,
    fontWeight: '600',
    lineHeight: 22,
    letterSpacing: -0.2,
  },
  body: {
    fontFamily: 'SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 16,
    fontWeight: '400',
    lineHeight: 22,
    letterSpacing: -0.1,
  },
  callout: {
    fontFamily: 'SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 15,
    fontWeight: '400',
    lineHeight: 20,
    letterSpacing: 0,
  },
  subheadline: {
    fontFamily: 'SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 14,
    fontWeight: '500',
    lineHeight: 18,
    letterSpacing: 0,
  },
  footnote: {
    fontFamily: 'SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 13,
    fontWeight: '400',
    lineHeight: 18,
    letterSpacing: 0,
  },
  caption: {
    fontFamily: 'SF Pro Text, -apple-system, BlinkMacSystemFont, sans-serif',
    fontSize: 12,
    fontWeight: '500',
    lineHeight: 16,
    letterSpacing: 0.1,
  },
};

// SPACING SCALE
const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  safe: 44, // Safe area
};

// RADIUS SCALE
const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  full: 9999,
};

// SHADOWS
const shadows = {
  subtle: '0 1px 2px rgba(0, 0, 0, 0.03)',
  card: '0 2px 8px rgba(0, 0, 0, 0.04)',
  elevated: '0 4px 16px rgba(0, 0, 0, 0.06)',
  glow: '0 0 24px rgba(91, 140, 255, 0.12)',
};

// ============================================================================
// MAIN APP COMPONENT
// ============================================================================

const OperatorKitUI = () => {
  return (
    <div style={styles.device}>
      <div style={styles.screen}>
        {/* Status Bar */}
        <div style={styles.statusBar}>
          <span style={styles.time}>2:30</span>
          <div style={styles.statusIcons}>
            <span style={styles.signal}>●●●●○</span>
            <span style={styles.wifi}>◐</span>
            <span style={styles.battery}>▮▮▮▯</span>
          </div>
        </div>

        {/* Header */}
        <div style={styles.header}>
          <div style={styles.headerLeft}>
            <div style={styles.logoContainer}>
              <div style={styles.logo}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <defs>
                    <linearGradient id="logoGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                      <stop offset="0%" stopColor="#5B8CFF" />
                      <stop offset="100%" stopColor="#7C5CFF" />
                    </linearGradient>
                  </defs>
                  <rect x="2" y="2" width="20" height="20" rx="6" fill="url(#logoGrad)" />
                  <circle cx="12" cy="12" r="4" fill="white" />
                </svg>
              </div>
              <span style={styles.logoText}>OperatorKit</span>
            </div>
          </div>
          <div style={styles.headerRight}>
            <button style={styles.settingsButton}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#9AA0A6" strokeWidth="1.8">
                <circle cx="12" cy="12" r="3" />
                <path d="M12 1v4M12 19v4M4.22 4.22l2.83 2.83M16.95 16.95l2.83 2.83M1 12h4M19 12h4M4.22 19.78l2.83-2.83M16.95 7.05l2.83-2.83" />
              </svg>
            </button>
          </div>
        </div>

        {/* Main Content */}
        <div style={styles.content}>
          {/* Input Field */}
          <div style={styles.inputContainer}>
            <div style={styles.micButton}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <defs>
                  <linearGradient id="micGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#5B8CFF" />
                    <stop offset="100%" stopColor="#7C5CFF" />
                  </linearGradient>
                </defs>
                <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" fill="url(#micGrad)" />
                <path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v4M8 23h8" stroke="url(#micGrad)" strokeWidth="2" strokeLinecap="round" />
              </svg>
            </div>
            <input
              type="text"
              placeholder="What do you want handled?"
              style={styles.inputField}
            />
          </div>

          {/* Section Header */}
          <div style={styles.sectionHeader}>
            <span style={styles.sectionTitle}>Recent Operations</span>
            <button style={styles.historyButton}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#9AA0A6" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12,6 12,12 16,14" />
              </svg>
              <span style={styles.historyText}>History</span>
            </button>
          </div>

          {/* Operation Cards */}
          <div style={styles.cardList}>
            {/* Card 1 - Email */}
            <div style={styles.card}>
              <div style={styles.cardIcon}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#6B7280" strokeWidth="1.8">
                  <rect x="2" y="4" width="20" height="16" rx="2" />
                  <path d="M22 6l-10 7L2 6" />
                </svg>
              </div>
              <div style={styles.cardContent}>
                <p style={styles.cardText}>
                  I hope you're doing well. I wanted to follow up taap, our meeting yesterday regarding the Q...
                </p>
                <span style={styles.cardMeta}>2.2 hours ago</span>
              </div>
            </div>

            {/* Card 2 - Calendar */}
            <div style={styles.card}>
              <div style={styles.cardIconAlt}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#6B7280" strokeWidth="1.8">
                  <rect x="3" y="4" width="18" height="18" rx="2" />
                  <line x1="16" y1="2" x2="16" y2="6" />
                  <line x1="8" y1="2" x2="8" y2="6" />
                  <line x1="3" y1="10" x2="21" y2="10" />
                </svg>
              </div>
              <div style={styles.cardContent}>
                <p style={styles.cardText}>
                  Key decisions: Approved new timeline, advocatey additional resources for Phase 2...
                </p>
                <span style={styles.cardMeta}>1 hour ago</span>
              </div>
            </div>

            {/* Card 3 - Task */}
            <div style={styles.card}>
              <div style={styles.cardIconSuccess}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5">
                  <polyline points="20,6 9,17 4,12" />
                </svg>
              </div>
              <div style={styles.cardContent}>
                <p style={styles.cardText}>
                  1. Update project roadmap - Due Friday. 2. stats ag'lus update to stakeholders...
                </p>
                <span style={styles.cardMeta}>2 days ago</span>
              </div>
            </div>
          </div>
        </div>

        {/* Floating Mic Button */}
        <div style={styles.floatingMicContainer}>
          <div style={styles.floatingMicGlow}></div>
          <button style={styles.floatingMic}>
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
              <defs>
                <linearGradient id="floatMicGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stopColor="#5B8CFF" />
                  <stop offset="100%" stopColor="#7C5CFF" />
                </linearGradient>
              </defs>
              <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" fill="url(#floatMicGrad)" />
              <path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v4M8 23h8" stroke="url(#floatMicGrad)" strokeWidth="2" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        {/* Home Indicator */}
        <div style={styles.homeIndicator}></div>
      </div>
    </div>
  );
};

// ============================================================================
// STYLES
// ============================================================================

const styles = {
  device: {
    width: 390,
    height: 844,
    background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)',
    borderRadius: 55,
    padding: 12,
    boxShadow: '0 50px 100px rgba(0,0,0,0.5)',
  },
  screen: {
    width: '100%',
    height: '100%',
    background: colors.background.primary,
    borderRadius: 44,
    overflow: 'hidden',
    position: 'relative',
    display: 'flex',
    flexDirection: 'column',
  },

  // Status Bar
  statusBar: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '14px 28px 8px',
    background: colors.background.primary,
  },
  time: {
    ...typography.subheadline,
    fontWeight: '600',
    color: colors.text.primary,
  },
  statusIcons: {
    display: 'flex',
    gap: 6,
    alignItems: 'center',
    fontSize: 12,
    color: colors.text.primary,
  },
  signal: { letterSpacing: -2 },
  wifi: { fontSize: 14 },
  battery: { letterSpacing: -1 },

  // Header
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: `${spacing.lg}px ${spacing.xl}px`,
  },
  headerLeft: {
    display: 'flex',
    alignItems: 'center',
  },
  logoContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: spacing.sm,
  },
  logo: {
    width: 32,
    height: 32,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoText: {
    ...typography.title,
    color: colors.text.primary,
  },
  headerRight: {
    display: 'flex',
    alignItems: 'center',
  },
  settingsButton: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    border: 'none',
    background: 'transparent',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  },

  // Main Content
  content: {
    flex: 1,
    padding: `0 ${spacing.xl}px`,
    overflowY: 'auto',
  },

  // Input Field
  inputContainer: {
    display: 'flex',
    alignItems: 'center',
    gap: spacing.md,
    background: colors.background.tertiary,
    borderRadius: radius.lg,
    border: `1px solid ${colors.border.default}`,
    padding: `${spacing.lg}px ${spacing.lg}px`,
    marginBottom: spacing.xxl,
  },
  micButton: {
    width: 36,
    height: 36,
    borderRadius: radius.md,
    background: colors.accent.muted,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  inputField: {
    flex: 1,
    border: 'none',
    background: 'transparent',
    ...typography.body,
    color: colors.text.primary,
    outline: 'none',
  },

  // Section Header
  sectionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  sectionTitle: {
    ...typography.headline,
    color: colors.text.primary,
  },
  historyButton: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    padding: `${spacing.xs}px ${spacing.sm}px`,
    borderRadius: radius.sm,
  },
  historyText: {
    ...typography.footnote,
    color: colors.icon.secondary,
  },

  // Cards
  cardList: {
    display: 'flex',
    flexDirection: 'column',
    gap: spacing.md,
  },
  card: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: spacing.md,
    background: colors.background.elevated,
    borderRadius: radius.xl,
    padding: spacing.lg,
    boxShadow: shadows.card,
    border: `1px solid ${colors.border.subtle}`,
  },
  cardIcon: {
    width: 36,
    height: 36,
    borderRadius: radius.md,
    background: colors.background.secondary,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  cardIconAlt: {
    width: 36,
    height: 36,
    borderRadius: radius.md,
    background: colors.background.secondary,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  cardIconSuccess: {
    width: 24,
    height: 24,
    borderRadius: radius.sm,
    background: '#10B981',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    marginTop: 6,
    marginLeft: 6,
    marginRight: 6,
  },
  cardContent: {
    flex: 1,
    minWidth: 0,
  },
  cardText: {
    ...typography.callout,
    color: colors.text.primary,
    margin: 0,
    marginBottom: spacing.xs,
    display: '-webkit-box',
    WebkitLineClamp: 2,
    WebkitBoxOrient: 'vertical',
    overflow: 'hidden',
  },
  cardMeta: {
    ...typography.caption,
    color: colors.text.tertiary,
  },

  // Floating Mic
  floatingMicContainer: {
    position: 'absolute',
    bottom: 100,
    left: '50%',
    transform: 'translateX(-50%)',
  },
  floatingMicGlow: {
    position: 'absolute',
    width: 96,
    height: 96,
    borderRadius: '50%',
    background: 'radial-gradient(circle, rgba(91, 140, 255, 0.15) 0%, transparent 70%)',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
  },
  floatingMic: {
    width: 72,
    height: 72,
    borderRadius: '50%',
    border: 'none',
    background: 'linear-gradient(135deg, rgba(91, 140, 255, 0.12) 0%, rgba(124, 92, 255, 0.12) 100%)',
    boxShadow: shadows.glow,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    position: 'relative',
  },

  // Home Indicator
  homeIndicator: {
    width: 134,
    height: 5,
    background: colors.text.primary,
    borderRadius: 3,
    margin: '8px auto 8px',
    opacity: 0.2,
  },
};

export default OperatorKitUI;

// ============================================================================
// DESIGN TOKENS EXPORT
// ============================================================================

export const DesignTokens = {
  colors,
  typography,
  spacing,
  radius,
  shadows,
};
