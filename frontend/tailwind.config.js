/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        // macOS window background
        'macos-bg': '#f6f6f6',
        'macos-panel': '#ffffff',
        'macos-sidebar': '#f0f0f0',
        'macos-header': '#e8e8e8',
        'macos-border': 'rgba(0,0,0,0.08)',
        'macos-divider': 'rgba(0,0,0,0.12)',

        // Primary blue gradient colors
        'primary-start': '#2667cc',
        'primary-end': '#59a6ff',
        'primary-dark': '#1a4fa0',

        // Text
        'text-primary': '#1d1d1f',
        'text-secondary': '#6e6e73',
        'text-tertiary': '#aeaeb2',
        'text-placeholder': '#c7c7cc',

        // Semantic
        'run-green': '#34c759',
        'run-cyan': '#32ade6',
        'run-orange': '#ff9f0a',
        'run-red': '#ff3b30',
        'run-gray': '#8e8e93',

        // Glass
        'glass-bg': 'rgba(255,255,255,0.72)',
        'glass-border': 'rgba(255,255,255,0.55)',
        'glass-shadow': 'rgba(0,0,0,0.08)',
      },
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          '"SF Pro Display"',
          '"SF Pro Text"',
          '"Helvetica Neue"',
          'Arial',
          'sans-serif',
        ],
        mono: [
          '"SF Mono"',
          '"Fira Code"',
          '"Fira Mono"',
          'Menlo',
          'Consolas',
          'monospace',
        ],
      },
      fontSize: {
        '2xs': ['0.625rem', { lineHeight: '0.875rem' }],
      },
      borderRadius: {
        'macos': '8px',
        'macos-sm': '6px',
        'macos-lg': '12px',
      },
      boxShadow: {
        'macos': '0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)',
        'macos-md': '0 4px 12px rgba(0,0,0,0.08), 0 2px 6px rgba(0,0,0,0.04)',
        'macos-lg': '0 8px 30px rgba(0,0,0,0.12), 0 4px 10px rgba(0,0,0,0.04)',
        'button-primary': '0 2px 8px rgba(38,103,204,0.25)',
        'glass': '0 4px 24px rgba(0,0,0,0.1), 0 1px 4px rgba(0,0,0,0.06)',
      },
      backdropBlur: {
        'macos': '20px',
        'glass': '24px',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-up': 'slideUp 0.25s ease-out',
        'slide-in-right': 'slideInRight 0.3s ease-out',
        'pulse-soft': 'pulseSoft 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideInRight: {
          '0%': { opacity: '0', transform: 'translateX(20px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' },
        },
        pulseSoft: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.5' },
        },
      },
    },
  },
  plugins: [],
}
