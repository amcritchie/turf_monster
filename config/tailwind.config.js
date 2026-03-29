const execSync = require('child_process').execSync
const studioPath = execSync('bundle show studio').toString().trim()

// Shared color palette from studio engine
const studioColors = require(`${studioPath}/tailwind/studio.tailwind.config.js`)

// Safelist all shades of custom brand colors so they're never purged
const brandColors = ['mint', 'navy', 'violet']
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
  theme: studioColors.theme,
}
