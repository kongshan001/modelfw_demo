// Colour palette, rebuilt from the visible reference only.
// These hex values follow the documented look of the scene.

export const PALETTE = {
  skyTop: 0x4f95de,
  skyMid: 0x7ba8de,
  horizon: 0xb8d6f0,
  cloudTop: 0xffffff,
  cloudUnder: 0xa9bfd4,
  seaShallow: 0x5a8fc8,
  seaDeep: 0x3d7adc,
  jacket: 0xe2622a,
  // Albedos are raised a little above their screen-space look so the physical
  // lights + ACES tone mapping still read as the intended colours.
  trousers: 0x34404f,
  helmet: 0xececec,
  bike: 0x2b2f36,
  skin: 0xd9a07a,
  backpack: 0x6d7d5a,
  hemiSky: 0xdfeaff,
  hemiGround: 0x8fb0d8,
  sun: 0xfff4e0,
};
