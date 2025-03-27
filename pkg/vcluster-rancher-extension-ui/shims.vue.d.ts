// Tell TypeScript to treat .vue files as 'any' by default:
declare module "*.vue" {
  const comp: any;
  export default comp;
}

// Force @rancher/shell modules to be 'any' so TS won't complain:
declare module "@rancher/shell/*" {
  const anything: any;
  export default anything;
}

// Example Vue augmentation (optional):
import { ComponentCustomProperties } from "vue";
declare module "@vue/runtime-core" {
  interface ComponentCustomProperties {
    $store: any;
    $router: any;
    $route: any;
    // etc...
  }
}
