/**
 * DraftKings Team Totals Scraper
 *
 * Scrapes World Cup 2026 team total goals odds from DraftKings.
 * Direct URL to Team Props → Total Team Goals subcategory.
 *
 * Usage:
 *   npm run scrape          # headless
 *   npm run scrape:headed   # visible browser for debugging
 *
 * Output: scripts/data/draftkings_team_totals.json
 */

const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const HEADED = process.argv.includes("--headed");
const OUTPUT_PATH = path.join(__dirname, "data", "draftkings_team_totals.json");
const SCREENSHOT_DIR = path.join(__dirname, "data");

const DK_URL =
  "https://sportsbook.draftkings.com/leagues/soccer/world-cup-2026?category=team-props&subcategory=total-team-goals";

const TEAM_NAME_MAP = {
  "mexico": "MEX", "south korea": "KOR", "korea republic": "KOR",
  "south africa": "RSA", "czechia": "CZE", "czech republic": "CZE",
  "canada": "CAN", "bosnia and herzegovina": "BIH", "bosnia & herzegovina": "BIH",
  "qatar": "QAT", "switzerland": "SUI", "brazil": "BRA", "morocco": "MAR",
  "haiti": "HAI", "scotland": "SCO", "united states": "USA", "usa": "USA",
  "paraguay": "PAR", "australia": "AUS", "turkey": "TUR", "türkiye": "TUR",
  "turkiye": "TUR", "germany": "GER", "curaçao": "CUW", "curacao": "CUW",
  "ivory coast": "CIV", "cote d'ivoire": "CIV", "côte d'ivoire": "CIV",
  "ecuador": "ECU", "netherlands": "NED", "japan": "JPN", "sweden": "SWE",
  "tunisia": "TUN", "belgium": "BEL", "egypt": "EGY", "iran": "IRN",
  "new zealand": "NZL", "spain": "ESP", "cape verde": "CPV", "cabo verde": "CPV",
  "saudi arabia": "KSA", "uruguay": "URU", "france": "FRA", "senegal": "SEN",
  "iraq": "IRQ", "norway": "NOR", "argentina": "ARG", "algeria": "ALG",
  "austria": "AUT", "jordan": "JOR", "portugal": "POR", "dr congo": "COD",
  "congo dr": "COD", "uzbekistan": "UZB", "colombia": "COL", "england": "ENG",
  "croatia": "CRO", "ghana": "GHA", "panama": "PAN",
};

function lookupShortName(teamName) {
  const normalized = teamName.trim().toLowerCase();
  if (TEAM_NAME_MAP[normalized]) return TEAM_NAME_MAP[normalized];
  for (const [key, val] of Object.entries(TEAM_NAME_MAP)) {
    if (normalized.includes(key) || key.includes(normalized)) return val;
  }
  return null;
}

async function scrape() {
  console.log(`Launching browser (${HEADED ? "headed" : "headless"})...`);

  const browser = await chromium.launch({ headless: !HEADED });
  const context = await browser.newContext({
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    viewport: { width: 1440, height: 900 },
  });
  const page = await context.newPage();

  try {
    console.log(`Navigating to ${DK_URL}...`);
    await page.goto(DK_URL, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, "dk_total_team_goals.png"), fullPage: true });

    // Extract text
    const pageContent = await page.evaluate(() => document.body.innerText);
    fs.writeFileSync(path.join(SCREENSHOT_DIR, "dk_total_team_goals_raw.txt"), pageContent);

    const lines = pageContent.split("\n").map(l => l.trim()).filter(Boolean);
    const results = [];

    // Parse structure:
    //   "Mexico: Team Total Goals"
    //   "Over"
    //   "0.5"
    //   "−1000"
    //   "Under"
    //   "0.5"
    //   "+390"
    //   "Over"
    //   "1.5"
    //   "−165"
    //   "Under"
    //   "1.5"
    //   "+100"
    //   ... (2.5, 3.5)

    // Track current game context (home VS away) to attach opponent
    let currentGameTeams = []; // [homeShort, awayShort]

    for (let i = 0; i < lines.length; i++) {
      // Detect game separator: "TeamA\nVS\nTeamB"
      if (lines[i] === "VS" && i > 0 && i + 1 < lines.length) {
        const home = lookupShortName(lines[i - 1]);
        const away = lookupShortName(lines[i + 1]);
        if (home && away) {
          currentGameTeams = [home, away];
        }
      }

      const headerMatch = lines[i].match(/^(.+?):\s*Team Total Goals$/i);
      if (!headerMatch) continue;

      const teamName = headerMatch[1].trim();
      const shortName = lookupShortName(teamName);
      if (!shortName) {
        console.log(`  ? Unknown team: "${teamName}"`);
        continue;
      }

      // Determine opponent from current game context
      let opponentShort = null;
      if (currentGameTeams.includes(shortName)) {
        opponentShort = currentGameTeams.find(t => t !== shortName) || null;
      }

      // Collect all O/U lines for this team until we hit another header or VS
      const overUnders = {};
      for (let j = i + 1; j < Math.min(lines.length, i + 60); j++) {
        // Stop at next team header or game separator
        if (lines[j].match(/: Team Total Goals$/i) || lines[j] === "VS") break;

        if (lines[j] === "Over" && j + 2 < lines.length) {
          const line = parseFloat(lines[j + 1]);
          const odds = parseInt(lines[j + 2].replace("−", "-"));
          if (!isNaN(line) && !isNaN(odds)) {
            if (!overUnders[line]) overUnders[line] = {};
            overUnders[line].over_odds = odds;
          }
        }
        if (lines[j] === "Under" && j + 2 < lines.length) {
          const line = parseFloat(lines[j + 1]);
          const odds = parseInt(lines[j + 2].replace("−", "-"));
          if (!isNaN(line) && !isNaN(odds)) {
            if (!overUnders[line]) overUnders[line] = {};
            overUnders[line].under_odds = odds;
          }
        }
      }

      // Pick the line with over_odds closest to even money (±100)
      // Distance: positive odds → |odds - 100|, negative odds → |odds + 100|
      let bestLine = null;
      let bestDistance = Infinity;
      for (const [lineStr, data] of Object.entries(overUnders)) {
        if (data.over_odds == null) continue;
        const distance = data.over_odds >= 0
          ? Math.abs(data.over_odds - 100)
          : Math.abs(data.over_odds + 100);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestLine = parseFloat(lineStr);
        }
      }

      if (bestLine !== null && overUnders[bestLine]) {
        const entry = {
          team_name: teamName,
          short_name: shortName,
          opponent_short_name: opponentShort,
          line: bestLine,
          over_odds: overUnders[bestLine].over_odds,
          under_odds: overUnders[bestLine].under_odds,
          all_lines: overUnders,
        };
        results.push(entry);
        console.log(`  ✓ ${teamName} (${shortName}) vs ${opponentShort}: O/U ${bestLine} [${entry.over_odds}/${entry.under_odds}]`);
      }
    }

    // Write results
    console.log(`\n=== ${results.length} team totals extracted ===`);
    fs.writeFileSync(OUTPUT_PATH, JSON.stringify(results, null, 2));
    console.log(`Written to ${OUTPUT_PATH}`);

    if (HEADED) {
      console.log("\nBrowser open for inspection. Ctrl+C to close.");
      await page.waitForTimeout(300000);
    }
  } catch (err) {
    console.error("Scraper error:", err.message);
    try { await page.screenshot({ path: path.join(SCREENSHOT_DIR, "dk_error.png"), fullPage: true }); } catch {}
  } finally {
    await browser.close();
  }
}

scrape().catch(console.error);
