import { PRODUCT_NAME } from "./constants";
import MyCustomPage from "./pages/index.vue";
import VClusterCreatePage from "./pages/create.vue";

const BLANK_CLUSTER = "_";

const routes = [
  {
    name: `${PRODUCT_NAME}-c-cluster-dashboard`,
    path: `/${encodeURIComponent(PRODUCT_NAME)}/c/:cluster/dashboard`,
    component: MyCustomPage,
    params: {
      cluster: BLANK_CLUSTER,
      product: PRODUCT_NAME,
    },
    meta: {
      product: PRODUCT_NAME,
      cluster: BLANK_CLUSTER,
    },
  },
  {
    name: `${PRODUCT_NAME}-c-cluster-create`,
    path: `/${encodeURIComponent(PRODUCT_NAME)}/c/:cluster/create`,
    component: VClusterCreatePage,
    params: {
      cluster: BLANK_CLUSTER,
      product: PRODUCT_NAME,
    },
    meta: {
      product: PRODUCT_NAME,
      cluster: BLANK_CLUSTER,
    },
  },
];

export default routes;
