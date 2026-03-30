const execSync = require('child_process').execSync
const studioPath = execSync('bundle show studio').toString().trim()

// Shared color palette from studio engine
const studioColors = require(`${studioPath}/tailwind/studio.tailwind.config.js`)

// Safelist all shades of custom brand colors so they're never purged
const brandColors = ['mint', 'navy', 'violet', 'primary', 'warning']
const shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]
const utilities = ['bg', 'text', 'border']
const safelist = brandColors.flatMap(color =>
  shades.flatMap(shade =>
    utilities.map(util => `${util}-${color}-${shade}`)
  )
)

module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    `${studioPath}/app/views/**/*.{erb,html}`,
  ],
  safelist,
  theme: {
    ...studioColors.theme,
    extend: {
      ...studioColors.theme.extend,
      colors: {
        ...studioColors.theme.extend.colors,
        primary: {
          DEFAULT: '#4BAF50',
          50:  '#e8f5e9',
          100: '#c8e6c9',
          200: '#a5d6a7',
          300: '#81c784',
          400: '#66bb6a',
          500: '#4BAF50',
          600: '#43A047',
          700: '#388E3C',
          800: '#2E7D32',
          900: '#1B5E20',
        },
        warning: {
          DEFAULT: '#FF7C47',
          50:  '#fff3ed',
          100: '#ffe2d1',
          200: '#ffc9a8',
          300: '#ffaa74',
          400: '#FF7C47',
          500: '#FF7C47',
          600: '#e5603a',
          700: '#cc4a2d',
          800: '#a33a24',
          900: '#7a2c1c',
        },
      },
    },
  },
}
