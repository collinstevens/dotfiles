// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Flamerix AI (https://flamerix.ai)
// Adapted from https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce

const SUMMARY_TIMER_ANCHOR = "[AgentSummary] Timer fired";
const MAX_TIMER_DELAY_MS = 2 ** 31 - 1;
const PROMISIFY_CUSTOM = Symbol.for("nodejs.util.promisify.custom");

const runsInCompiledBun =
  typeof Bun !== "undefined" && /^(\/\$bunfs\/|B:\/~BUN\/)/.test(Bun.main);

function suppressAgentSummaryTimers() {
  const isSummaryTimerByCallback = new WeakMap();

  function isSummaryTimer(callback) {
    if (typeof callback !== "function") return false;
    let isSummary = isSummaryTimerByCallback.get(callback);
    if (isSummary === undefined) {
      try {
        isSummary = Function.prototype.toString.call(callback).includes(SUMMARY_TIMER_ANCHOR);
      } catch {
        isSummary = false;
      }
      isSummaryTimerByCallback.set(callback, isSummary);
    }
    return isSummary;
  }

  const wrapperByTimer = new Map();

  function wrapTimer(schedule) {
    if (typeof schedule !== "function") return schedule;
    if (wrapperByTimer.has(schedule)) return wrapperByTimer.get(schedule);

    const wrapper = function (callback, delay, ...args) {
      if (!isSummaryTimer(callback)) return schedule(callback, delay, ...args);
      const inertTimer = schedule(() => {}, MAX_TIMER_DELAY_MS);
      inertTimer?.unref?.();
      return inertTimer;
    };
    Object.defineProperty(wrapper, "name", { value: schedule.name });
    if (schedule.__promisify__) wrapper.__promisify__ = schedule.__promisify__;
    if (schedule[PROMISIFY_CUSTOM]) wrapper[PROMISIFY_CUSTOM] = schedule[PROMISIFY_CUSTOM];

    wrapperByTimer.set(schedule, wrapper);
    return wrapper;
  }

  const timers = require("timers");
  for (const name of ["setTimeout", "setInterval"]) {
    globalThis[name] = wrapTimer(globalThis[name]);
    timers[name] = wrapTimer(timers[name]);
  }
}

if (runsInCompiledBun) suppressAgentSummaryTimers();
