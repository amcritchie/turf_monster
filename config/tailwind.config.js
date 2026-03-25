const execSync = require('child_process').execSync
const studioPath = execSync('bundle show studio').toString().trim()

// Shared color palette from studio engine
const studioColors = require(`${studioPath}/tailwind/studio.tailwind.config.js`)

module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    `${studioPath}/app/views/**/*.{erb,html}`,
  ],
  theme: studioColors.theme,
}
