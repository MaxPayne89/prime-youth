/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./assets/**/*.js",
    "./lib/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        // Klass Hero Superhero Brand Colors
        'hero': {
          blue: {
            50: '#E5F9FF',
            100: '#CCF3FF',
            200: '#99E7FF',
            300: '#66DBFF',
            400: '#33CFFF',
            500: '#00D4FF', // Primary brand blue (bright cyan from localhost:3000)
            600: '#00A7CC',
            700: '#007D99',
            800: '#005466',
            900: '#002A33',
          },
          yellow: {
            50: '#FFFEF5',
            100: '#FFFCEB',
            200: '#FFFAD6',
            300: '#FFF7C2',
            400: '#FFF5AD',
            500: '#FFFF36', // Primary brand yellow
            600: '#CCCC2B',
            700: '#999920',
            800: '#666616',
            900: '#33330B',
          },
          grey: {
            50: '#F7F7F7',
            100: '#EFEFEF',
            200: '#DFDFDF',
            300: '#CFCFCF',
            400: '#C7C7C7', // Brand grey
            500: '#A8A8A8',
            600: '#8A8A8A',
            700: '#6B6B6B',
            800: '#4D4D4D',
            900: '#2E2E2E',
          },
          pink: {
            50: '#FFEAC9', // Primary brand background
            100: '#FFE4B8',
            200: '#FFDEA7',
            300: '#FFD896',
            400: '#FFD285',
            500: '#FFCC74',
            600: '#CCA35D',
            700: '#997A46',
            800: '#66522E',
            900: '#332917',
          },
          cream: {
            50: '#FDFCF9',
            100: '#F5F1E8', // Primary cream background (from localhost:3000)
            200: '#EDE9E0',
            300: '#E5E1D8',
            400: '#DDD9D0',
            500: '#D5D1C8',
            600: '#ABA8A0',
            700: '#807E78',
            800: '#555450',
            900: '#2B2A28',
          },
          black: {
            DEFAULT: '#000000', // Primary brand text
            50: '#1A1A1A',
            100: '#333333',
            200: '#4D4D4D',
            300: '#666666',
            400: '#808080',
            500: '#999999',
            600: '#B3B3B3',
            700: '#CCCCCC',
            800: '#E6E6E6',
            900: '#F2F2F2',
          }
        }
      },
      fontFamily: {
        'display': ['Plus Jakarta Sans', 'Inter', 'system-ui', 'sans-serif'],
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
    require('./assets/vendor/heroicons'),
  ],
}