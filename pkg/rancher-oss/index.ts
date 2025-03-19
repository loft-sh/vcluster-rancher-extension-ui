import { importTypes } from "@rancher/auto-import";
import { IPlugin, PanelLocation } from "@shell/core/types";
import extensionRouting from "./routes";
import { setupButtonInjector } from "./setupButtonInjector";

export default function (plugin: IPlugin): void {
  importTypes(plugin);

  plugin.metadata = require("./package.json");

  plugin.addProduct(require("./product"));
  plugin.addRoutes(extensionRouting);

  plugin.addPanel(
    PanelLocation.DETAILS_MASTHEAD,
    { resource: ["provisioning.cattle.io.cluster"] },
    { component: () => import("./components/VClusterClusterCreateItem.vue") },
  );

  setTimeout(() => {
    setupButtonInjector();
  }, 1000);
}
