{{flutter_js}}
{{flutter_build_config}}

(async function () {
  if (typeof window.__cartelhoodClearLegacyWorker === "function") {
    await window.__cartelhoodClearLegacyWorker();
  }
  _flutter.loader.load();
})();
