{{flutter_js}}
{{flutter_build_config}}

const neoTaskBuildId = '20260801-5';
const jsBuild = _flutter.buildConfig.builds.find(
  (build) => typeof build.mainJsPath === 'string',
);

// A query-versioned entrypoint bypasses a legacy Flutter worker that might
// still control one final iOS navigation after it has been unregistered.
if (jsBuild) {
  jsBuild.mainJsPath = `${jsBuild.mainJsPath}?v=${neoTaskBuildId}`;
}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      // Let Flutter select the smallest compatible renderer for the current
      // browser instead of forcing the heavier full CanvasKit download on
      // every iPad/iPhone refresh.
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (error) {
      const message = document.getElementById('boot-message');
      const spinner = document.querySelector('#boot-status .spinner');
      const retry = document.getElementById('boot-retry');
      if (message) message.textContent = 'تعذّر تشغيل التطبيق';
      if (spinner) spinner.style.display = 'none';
      if (retry) retry.style.display = 'block';
      console.error('NeoTask Flutter bootstrap failed:', error);
    }
  },
});
