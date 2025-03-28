const baseConfig = require("./.shell/pkg/vue.config")(__dirname);

module.exports = {
  ...baseConfig,
  chainWebpack: (config) => {
    if (typeof baseConfig.chainWebpack === "function") {
      baseConfig.chainWebpack(config);
    }

    // DISABLE TS CHECKER for builds because it's blocking it, due to module resolution between our app and @shell/rancher
    config.plugins.delete("fork-ts-checker");
  },
};
