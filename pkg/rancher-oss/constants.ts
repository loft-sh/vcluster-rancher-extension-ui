const PRODUCT_NAME = "vCluster";
const LOFT_CHART_URL = "https://charts.loft.sh";
const RANCHER_CONSTANTS = {
  MAIN_LAYOUT_CLASS_NAME: "main-layout",
  SIDE_NAV_CLASS_NAME: "side-nav",
  VCLUSTER_PAGE_ACTIVE_CLASS_NAME: "vcluster-page-active",
  VCLUSTER_PROJECT_LABEL: "loft.sh/vcluster-project-uid",
  VCLUSTER_SERVICE_LABEL: "loft.sh/vcluster-service-uid",
} as const;

export { PRODUCT_NAME, LOFT_CHART_URL, RANCHER_CONSTANTS };
