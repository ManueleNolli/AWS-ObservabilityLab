"use strict";

const ACTIONS = {
  login: { method: "POST", path: "/api/login" },
  checkout: { method: "POST", path: "/api/checkout" },
  search: { method: "GET", path: "/api/search", query: () => ({ q: randomItem(SEARCH_TERMS) }) },
  error: { method: "POST", path: "/api/error" },
};

const SEARCH_TERMS = ["shoes", "laptop", "coffee", "books", "headphones"];
const BURST_SIZE = 20;
const BURST_WINDOW_MS = 3000;
const MAX_ROWS = 100;

const activity = document.getElementById("activity");

function randomItem(items) {
  return items[Math.floor(Math.random() * items.length)];
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function send(name) {
  const { method, path, query } = ACTIONS[name];
  const url = query ? `${path}?${new URLSearchParams(query())}` : path;
  const started = performance.now();
  let status;
  try {
    status = (await fetch(url, { method })).status;
  } catch {
    status = "network error";
  }
  record(`${method} ${url}`, status, performance.now() - started);
}

/** Fire a burst of mixed requests, spread randomly over a few seconds. */
async function burst() {
  const names = Object.keys(ACTIONS);
  const requests = Array.from({ length: BURST_SIZE }, async () => {
    await sleep(Math.random() * BURST_WINDOW_MS);
    await send(randomItem(names));
  });
  await Promise.all(requests);
}

function record(request, status, latencyMs) {
  const row = activity.insertRow(0);
  row.className = statusClass(status);
  for (const text of [new Date().toLocaleTimeString(), request, status, `${Math.round(latencyMs)} ms`]) {
    row.insertCell().textContent = text;
  }
  while (activity.rows.length > MAX_ROWS) {
    activity.deleteRow(-1);
  }
}

function statusClass(status) {
  if (typeof status !== "number" || status >= 500) return "error";
  if (status >= 400) return "warning";
  return "ok";
}

document.querySelectorAll("[data-action]").forEach((button) => {
  button.addEventListener("click", async () => {
    const action = button.dataset.action;
    button.disabled = true;
    try {
      await (action === "random" ? burst() : send(action));
    } finally {
      button.disabled = false;
    }
  });
});

document.getElementById("clear").addEventListener("click", () => activity.replaceChildren());
