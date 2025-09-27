/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./*.html", "./assets/**/*.js"],
  theme: {
    extend: {
      colors: {
        // Prime Youth Brand Colors with full shade palettes
        'prime': {
          yellow: {
            50: '#FFFCEB',
            100: '#FFF8D1',
            200: '#FFF0A8',
            300: '#FFE875',
            400: '#FFD700', // Primary brand yellow
            500: '#E6C200',
            600: '#CCAD00',
            700: '#B39700',
            800: '#997800',
            900: '#805C00',
          },
          magenta: {
            50: '#FFF0F7',
            100: '#FFE1F0',
            200: '#FFC3E1',
            300: '#FFA5D2',
            400: '#FF1493', // Primary brand magenta
            500: '#E6127D',
            600: '#CC1067',
            700: '#B30E51',
            800: '#990C3B',
            900: '#800A25',
          },
          cyan: {
            50: '#F0FDFC',
            100: '#E1FBF9',
            200: '#C3F7F3',
            300: '#A5F3ED',
            400: '#00CED1', // Primary brand cyan
            500: '#00B4B7',
            600: '#009A9D',
            700: '#008083',
            800: '#006669',
            900: '#004C4F',
          }
        }
      },
      fontFamily: {
        'sans': ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'bounce-gentle': 'bounceGentle 2s infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        bounceGentle: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-5px)' },
        }
      },
      boxShadow: {
        'glass': '0 8px 32px 0 rgba(31, 38, 135, 0.37)',
        'card': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
      },
      backdropBlur: {
        'glass': '10px',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
  ],
}