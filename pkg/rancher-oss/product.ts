import { IPlugin } from "@shell/core/types";
import { PRODUCT_NAME } from "./constants";

export function init($plugin: IPlugin, store: any) {
  const { product } = $plugin.DSL(store, PRODUCT_NAME);

  product({
    svg: require("./assets/vclusterLogo.svg"),
    inStore: "management",
    weight: 100,
    to: {
      name: `${PRODUCT_NAME}-c-cluster-dashboard`,
      path: `/${PRODUCT_NAME}/c/:cluster/dashboard`,
      params: {
        product: PRODUCT_NAME,
        cluster: "_",
      },
    },
  });
}
