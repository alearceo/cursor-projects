const ZIP_RE = /^\d{5}$/;

const WMO = {
  0: { label: "Clear", icon: "☀️" },
  1: { label: "Mostly clear", icon: "🌤️" },
  2: { label: "Partly cloudy", icon: "⛅" },
  3: { label: "Overcast", icon: "☁️" },
  45: { label: "Fog", icon: "🌫️" },
  48: { label: "Fog", icon: "🌫️" },
  51: { label: "Light drizzle", icon: "🌦️" },
  53: { label: "Drizzle", icon: "🌧️" },
  55: { label: "Heavy drizzle", icon: "🌧️" },
  61: { label: "Light rain", icon: "🌧️" },
  63: { label: "Rain", icon: "🌧️" },
  65: { label: "Heavy rain", icon: "🌧️" },
  71: { label: "Light snow", icon: "🌨️" },
  73: { label: "Snow", icon: "❄️" },
  75: { label: "Heavy snow", icon: "❄️" },
  77: { label: "Snow grains", icon: "🌨️" },
  80: { label: "Rain showers", icon: "🌦️" },
  81: { label: "Showers", icon: "🌧️" },
  82: { label: "Heavy showers", icon: "⛈️" },
  85: { label: "Snow showers", icon: "🌨️" },
  86: { label: "Snow showers", icon: "🌨️" },
  95: { label: "Thunderstorm", icon: "⛈️" },
  96: { label: "Thunderstorm & hail", icon: "⛈️" },
  99: { label: "Severe thunderstorm", icon: "⛈️" },
};

function wmoInfo(code) {
  return WMO[code] ?? { label: "Mixed", icon: "🌡️" };
}

function isWetCode(code) {
  if (code == null) return false;
  return (
    (code >= 51 && code <= 67) ||
    (code >= 71 && code <= 77) ||
    (code >= 80 && code <= 82) ||
    (code >= 85 && code <= 99)
  );
}

function computeRunIndex({ apparentC, gustMph, weatherCode, usAqi }) {
  let score = 100;
  const bullets = [];

  if (apparentC != null) {
    const f = apparentC * (9 / 5) + 32;
    if (f >= 95) {
      score -= 30;
      bullets.push("Very hot feels-like — hydrate, slow pace, seek shade.");
    } else if (f >= 88) {
      score -= 22;
      bullets.push("High heat index — plan for water and easier effort.");
    } else if (f >= 82) {
      score -= 12;
      bullets.push("Warm — bring fluids and expect higher perceived effort.");
    } else if (f <= 14) {
      score -= 28;
      bullets.push("Bitter cold — cover skin, watch for ice on bridges and shade.");
    } else if (f <= 28) {
      score -= 16;
      bullets.push("Freezing possible — mind slick spots and shorter strides on corners.");
    }
  }

  if (gustMph != null) {
    if (gustMph >= 40) {
      score -= 24;
      bullets.push("Strong gusts — debris risk; avoid exposed waterfront routes.");
    } else if (gustMph >= 32) {
      score -= 14;
      bullets.push("Gusty wind — expect crosswinds on open streets.");
    } else if (gustMph >= 25) {
      score -= 8;
      bullets.push("Breezy — comfortable for many, annoying for tempo work.");
    }
  }

  if (weatherCode != null) {
    const wet = isWetCode(weatherCode);
    if (weatherCode >= 95) {
      score -= 35;
      bullets.push("Storms nearby — avoid tall/empty blocks; postpone if lightning.");
    } else if ([65, 75, 82, 86].includes(weatherCode)) {
      score -= 28;
      bullets.push("Heavy precip — reduced grip; watch painted crosswalks and metal plates.");
    } else if (wet) {
      score -= 18;
      bullets.push("Wet roads — braking distance up; puddles hide potholes.");
    } else if (weatherCode === 45 || weatherCode === 48) {
      score -= 10;
      bullets.push("Low visibility — drivers may react late; favor lit paths.");
    }
  }

  if (usAqi != null && Number.isFinite(usAqi)) {
    if (usAqi >= 151) {
      score -= 30;
      bullets.push("Unhealthy air — shorten easy runs or move indoors.");
    } else if (usAqi >= 101) {
      score -= 18;
      bullets.push("Sensitive groups: consider shorter duration or easier route.");
    } else if (usAqi >= 51) {
      score -= 6;
      bullets.push("Moderate AQI — fine for most; optional mask near traffic.");
    }
  }

  score = Math.max(0, Math.min(100, Math.round(score)));
  if (bullets.length === 0) {
    bullets.push("Conditions look favorable for a steady city run.");
  }
  return { score, bullets };
}

function verdictForScore(s) {
  if (s >= 80) return { text: "Good window to get miles in.", tone: "good" };
  if (s >= 60) return { text: "Runnable — adjust pace and gear.", tone: "mid" };
  if (s >= 40) return { text: "Challenging — pick safer streets and shorten if needed.", tone: "mid" };
  return { text: "Rough for pavement running — consider timing or indoor backup.", tone: "bad" };
}

async function fetchZip(zip) {
  const res = await fetch(`https://api.zippopotam.us/us/${zip}`);
  if (!res.ok) throw new Error("That zip was not found. Try a valid U.S. five-digit code.");
  const data = await res.json();
  const place = data.places[0];
  const lat = parseFloat(place.latitude);
  const lon = parseFloat(place.longitude);
  const name = `${place["place name"]}, ${place["state abbreviation"]}`;
  return { lat, lon, name };
}

async function fetchWeather(lat, lon) {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lon),
    current: [
      "temperature_2m",
      "relative_humidity_2m",
      "apparent_temperature",
      "precipitation",
      "rain",
      "weather_code",
      "wind_speed_10m",
      "wind_gusts_10m",
    ].join(","),
    hourly: [
      "temperature_2m",
      "precipitation_probability",
      "precipitation",
      "weather_code",
      "wind_speed_10m",
    ].join(","),
    forecast_days: "2",
    timezone: "auto",
    wind_speed_unit: "mph",
    temperature_unit: "fahrenheit",
  });
  const res = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`);
  if (!res.ok) throw new Error("Weather data could not be loaded.");
  return res.json();
}

async function fetchAir(lat, lon) {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lon),
    current: "us_aqi,pm2_5",
    timezone: "auto",
  });
  const res = await fetch(`https://air-quality-api.open-meteo.com/v1/air-quality?${params}`);
  if (!res.ok) return null;
  return res.json();
}

async function fetchNwsAlerts(lat, lon) {
  try {
    const url = `https://api.weather.gov/alerts/active?point=${lat},${lon}`;
    const res = await fetch(url, {
      headers: {
        Accept: "application/geo+json",
        "User-Agent": "StrideCheck/1.0 (city runner conditions; contact: local)",
      },
    });
    if (!res.ok) return [];
    const data = await res.json();
    const feats = data.features ?? [];
    return feats.slice(0, 6).map((f) => {
      const p = f.properties ?? {};
      return {
        headline: p.headline || p.event || "Alert",
        description: (p.description || "").slice(0, 280),
        severity: p.severity,
      };
    });
  } catch {
    return null;
  }
}

/** Open-Meteo returns wind in mph when `wind_speed_unit=mph` is set. */
function mphValue(v) {
  if (v == null || Number.isNaN(v)) return null;
  return v;
}

function setScoreRing(score, tone) {
  const circle = document.getElementById("score-ring-fill");
  const c = 2 * Math.PI * 52;
  const offset = c * (1 - score / 100);
  circle.style.strokeDashoffset = String(offset);
  circle.classList.remove("score-good", "score-mid", "score-bad");
  circle.classList.add(`score-${tone}`);
}

function renderCurrent(weather) {
  const cur = weather.current;
  const w = cur.weather_code;
  const info = wmoInfo(w);
  const gust = mphValue(cur.wind_gusts_10m);
  const wind = mphValue(cur.wind_speed_10m);
  const rows = [
    ["Feels like", `${Math.round(cur.apparent_temperature)}°F`],
    ["Conditions", `${info.icon} ${info.label}`],
    [
      "Wind",
      wind != null
        ? `${Math.round(wind)} mph${gust != null ? ` · gusts ${Math.round(gust)} mph` : ""}`
        : "—",
    ],
    ["Humidity", `${cur.relative_humidity_2m ?? "—"}%`],
    ["Precip (now)", `${(cur.precipitation ?? 0) > 0 ? "Yes" : "None"}`],
  ];
  const el = document.getElementById("current-metrics");
  el.innerHTML = rows
    .map(
      ([dt, dd]) => `<div class="metric-row"><dt>${dt}</dt><dd>${dd}</dd></div>`
    )
    .join("");
}

function renderAir(air) {
  const el = document.getElementById("air-metrics");
  if (!air?.current) {
    el.innerHTML =
      '<div class="metric-row"><dt>AQI</dt><dd>—</dd></div><p style="margin:0;color:var(--muted);font-size:0.85rem">Air quality unavailable for this point.</p>';
    return;
  }
  const aqi = air.current.us_aqi;
  const pm = air.current.pm2_5;
  let band = "—";
  if (aqi != null) {
    if (aqi <= 50) band = "Good";
    else if (aqi <= 100) band = "Moderate";
    else if (aqi <= 150) band = "Unhealthy (sensitive)";
    else if (aqi <= 200) band = "Unhealthy";
    else if (aqi <= 300) band = "Very unhealthy";
    else band = "Hazardous";
  }
  const rows = [
    ["US AQI", aqi != null ? `${Math.round(aqi)} (${band})` : "—"],
    ["PM2.5", pm != null ? `${pm.toFixed(1)} µg/m³` : "—"],
  ];
  el.innerHTML = rows
    .map(
      ([dt, dd]) => `<div class="metric-row"><dt>${dt}</dt><dd>${dd}</dd></div>`
    )
    .join("");
}

function renderHourly(weather) {
  const hourly = weather.hourly;
  if (!hourly?.time?.length) return;
  const now = new Date();
  let startIdx = hourly.time.findIndex((t) => new Date(t) >= now);
  if (startIdx < 0) startIdx = 0;
  const slice = hourly.time.slice(startIdx, startIdx + 12);
  const el = document.getElementById("hourly-strip");
  el.innerHTML = slice
    .map((t, i) => {
      const idx = startIdx + i;
      const code = hourly.weather_code[idx];
      const info = wmoInfo(code);
      const pop = hourly.precipitation_probability[idx];
      const time = new Date(t);
      const label = time.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
      return `<div class="hourly-pill" title="${info.label}">
        <div class="t">${label}</div>
        <div class="w">${info.icon}</div>
        <div class="d">${pop}% rain</div>
      </div>`;
    })
    .join("");
}

function renderAlerts(alerts) {
  const card = document.getElementById("alerts-card");
  const body = document.getElementById("alerts-body");
  if (alerts === null) {
    body.innerHTML =
      '<p style="margin:0">Alerts could not be loaded (network or browser restrictions). Weather above still reflects local Open-Meteo data.</p>';
    return;
  }
  if (!alerts.length) {
    body.innerHTML =
      '<p style="margin:0">No active NWS alerts for this coordinate at the moment.</p>';
    return;
  }
  body.innerHTML = alerts
    .map(
      (a) => `<div class="alert-item">
      <div class="alert-head">${escapeHtml(a.headline)}</div>
      <div style="font-size:0.85rem;color:var(--muted)">${escapeHtml(a.description)}${a.description.length >= 280 ? "…" : ""}</div>
    </div>`
    )
    .join("");
  card.style.display = "block";
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function setLoading(loading) {
  const btn = document.getElementById("submit-btn");
  const text = btn.querySelector(".btn-text");
  const spin = btn.querySelector(".btn-spinner");
  btn.disabled = loading;
  text.hidden = loading;
  spin.hidden = !loading;
}

function showError(msg) {
  const e = document.getElementById("error-msg");
  e.textContent = msg;
  e.hidden = false;
}

function hideError() {
  const e = document.getElementById("error-msg");
  e.hidden = true;
  e.textContent = "";
}

document.getElementById("zip-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  hideError();
  const input = document.getElementById("zip-input");
  const zip = input.value.trim();
  if (!ZIP_RE.test(zip)) {
    showError("Enter a valid five-digit U.S. zip code.");
    return;
  }

  setLoading(true);
  try {
    const { lat, lon, name } = await fetchZip(zip);
    const [weather, air, alerts] = await Promise.all([
      fetchWeather(lat, lon),
      fetchAir(lat, lon),
      fetchNwsAlerts(lat, lon),
    ]);

    const cur = weather.current;
    const apparentF = cur.apparent_temperature;
    const apparentC = (apparentF - 32) * (5 / 9);
    const gustMph = mphValue(cur.wind_gusts_10m);
    const usAqi = air?.current?.us_aqi ?? null;

    const { score, bullets } = computeRunIndex({
      apparentC,
      gustMph,
      weatherCode: cur.weather_code,
      usAqi,
    });
    const v = verdictForScore(score);

    document.getElementById("place-name").textContent = name;
    document.getElementById("coords-line").textContent = `${lat.toFixed(4)}°, ${lon.toFixed(4)}°`;

    document.getElementById("score-num").textContent = String(score);
    document.getElementById("verdict").textContent = v.text;
    setScoreRing(score, v.tone);

    const ul = document.getElementById("score-bullets");
    ul.innerHTML = bullets.map((b) => `<li>${escapeHtml(b)}</li>`).join("");

    renderCurrent(weather);
    renderAir(air);
    renderHourly(weather);
    renderAlerts(alerts);

    document.getElementById("results").hidden = false;
    document.getElementById("results").scrollIntoView({ behavior: "smooth", block: "start" });
  } catch (err) {
    showError(err.message || "Something went wrong. Try again.");
  } finally {
    setLoading(false);
  }
});
