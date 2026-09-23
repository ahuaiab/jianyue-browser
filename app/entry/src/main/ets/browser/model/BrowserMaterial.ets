import { uiMaterial } from '@kit.ArkUI';
import { safariChromeSurfaceBackgroundColor } from './BrowserVisualMetrics';

/**
 * One native material preset for every browser-owned floating surface.
 * Keeping the values here prevents the tab overview, library sheets and
 * browser chrome from drifting apart as each component evolves.
 */
export const SAFARI_IMMERSIVE_MATERIAL_STYLE: uiMaterial.ImmersiveStyle =
  uiMaterial.ImmersiveStyle.ULTRA_THICK;
export const SAFARI_IMMERSIVE_MATERIAL_TINT: string | undefined = undefined;
export const SAFARI_IMMERSIVE_MATERIAL_APPLY_SHADOW: boolean = true;
export const SAFARI_IMMERSIVE_MATERIAL_INTERACTIVE: boolean = true;
/** Undefined lets the system supply the platform light-effect color. */
export const SAFARI_IMMERSIVE_MATERIAL_LIGHT_EFFECT_COLOR: string | undefined = undefined;

export function safariImmersiveMaterialSupported(): boolean {
  return uiMaterial.isImmersiveMaterialSupported();
}

/** Create a fresh native material instance for each host node. */
export function safariImmersiveMaterial(): uiMaterial.ImmersiveMaterial {
  return new uiMaterial.ImmersiveMaterial({
    style: SAFARI_IMMERSIVE_MATERIAL_STYLE,
    materialColor: SAFARI_IMMERSIVE_MATERIAL_TINT,
    applyShadow: SAFARI_IMMERSIVE_MATERIAL_APPLY_SHADOW,
    interactive: SAFARI_IMMERSIVE_MATERIAL_INTERACTIVE,
    lightEffect: { color: SAFARI_IMMERSIVE_MATERIAL_LIGHT_EFFECT_COLOR }
  });
}

/** Use the native filter only where the platform supports it. */
export function safariImmersiveMaterialIfSupported(): uiMaterial.ImmersiveMaterial | undefined {
  return safariImmersiveMaterialSupported() ? safariImmersiveMaterial() : undefined;
}

/** Semantic alias for compact action controls that share the browser chrome material. */
export function safariImmersiveControlMaterialIfSupported(): uiMaterial.ImmersiveMaterial | undefined {
  return safariImmersiveMaterialIfSupported();
}

/** Pair the native filter with the translucent base or the opaque fallback. */
export function safariImmersiveSurfaceBackgroundColor(): string {
  return safariChromeSurfaceBackgroundColor(safariImmersiveMaterialSupported());
}
