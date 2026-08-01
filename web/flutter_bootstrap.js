{{flutter_js}}
{{flutter_build_config}}

const neoTaskBuildId = '20260801-3';
const jsBuild = _flutter.buildConfig.builds.find(
  (build) => typeof build.mainJsPath === 'string',
);

// A query-versioned entrypoint bypasses a legacy Flutter worker that might
// still control one final iOS navigation after it has been unregistered.
if (jsBuild) {
  jsBuild.mainJsPath = `${jsBuild.mainJsPath}?v=${neoTaskBuildId}`;
}

const engineConfig = {
  // The full CanvasKit variant is the compatibility path for WebKit/iOS.
  canvasKitVariant: 'full',
};

_flutter.loader.load({
  config: engineConfig,
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine(engineConfig);
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
