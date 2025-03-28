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
