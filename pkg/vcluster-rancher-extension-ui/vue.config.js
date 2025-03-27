const baseConfig = require("./.shell/pkg/vue.config")(__dirname);

module.exports = {
  ...baseConfig,

  // If baseConfig already has chainWebpack, we must wrap it
  chainWebpack: (config) => {
    // Call the base config's chainWebpack first (if it exists)
    if (typeof baseConfig.chainWebpack === "function") {
      baseConfig.chainWebpack(config);
    }

    // Then delete the Fork TS checker plugin
    config.plugins.delete("fork-ts-checker");
  },
};
