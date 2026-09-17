import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import {
  PermissionDecision,
  PermissionPromptPort,
  WebGeolocationEventPort,
  WebPermissionCoordinator,
  WebPermissionRequestHandler,
  WebPermissionRequestPort,
  WebResourceKind,
  webResourceKindForProtectedResource
} from './WebPermissionCoordinator';

const CAMERA_PERMISSION: Permissions = 'ohos.permission.CAMERA';
const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';
const LOCATION_PERMISSION: Permissions = 'ohos.permission.LOCATION';
const APPROXIMATE_LOCATION_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';

function systemPermissionsForResource(resource: WebResourceKind): Array<Permissions> {
  switch (resource) {
    case WebResourceKind.CAMERA:
      return [CAMERA_PERMISSION];
    case WebResourceKind.MICROPHONE:
      return [MICROPHONE_PERMISSION];
    case WebResourceKind.GEOLOCATION:
      return [APPROXIMATE_LOCATION_PERMISSION, LOCATION_PERMISSION];
    default:
      return [];
  }
}

class HarmonyPermissionPrompt implements PermissionPromptPort {
  private readonly context: Context;
  private readonly atManager: abilityAccessCtrl.AtManager;

  constructor(context: Context) {
    this.context = context;
    this.atManager = abilityAccessCtrl.createAtManager();
  }

  async confirm(_origin: string, resource: WebResourceKind,
    _isPrivate: boolean): Promise<PermissionDecision> {
    const permissions: Array<Permissions> = systemPermissionsForResource(resource);
    if (permissions.length === 0) {
      return PermissionDecision.DENY;
    }
    try {
      const result = await this.atManager.requestPermissionsFromUser(this.context, permissions);
      const allGranted: boolean = result.authResults.length === permissions.length &&
        result.authResults.every((status: number) => status === 0);
      return allGranted ? PermissionDecision.ALLOW : PermissionDecision.DENY;
    } catch (_error) {
      return PermissionDecision.DENY;
    }
  }
}

/** Bridges ArkWeb resource requests to HarmonyOS runtime permissions. */
export class HarmonyWebPermissionHandler implements WebPermissionRequestHandler {
  private readonly coordinator: WebPermissionCoordinator;

  constructor(context: Context) {
    this.coordinator = new WebPermissionCoordinator(new HarmonyPermissionPrompt(context));
  }

  onPermissionRequest(request: WebPermissionRequestPort, isPrivate: boolean): void {
    void this.handlePermissionRequest(request, isPrivate);
  }

  onGeolocationShow(event: WebGeolocationEventPort, isPrivate: boolean): void {
    void this.handleGeolocationRequest(event, isPrivate);
  }

  private async handlePermissionRequest(
    request: WebPermissionRequestPort,
    isPrivate: boolean
  ): Promise<void> {
    let resources: Array<string> = [];
    try {
      resources = request.getAccessibleResource();
    } catch (_error) {
      request.deny();
      return;
    }
    if (resources.length === 0) {
      request.deny();
      return;
    }
    const origin: string = request.getOrigin();
    let allowed: boolean = true;
    for (const resource of resources) {
      const kind: WebResourceKind = webResourceKindForProtectedResource(resource);
      const decision: PermissionDecision = await this.coordinator.decide(origin, kind, isPrivate);
      if (decision !== PermissionDecision.ALLOW) {
        allowed = false;
        break;
      }
    }
    if (allowed) {
      request.grant(resources);
    } else {
      request.deny();
    }
  }

  private async handleGeolocationRequest(
    event: WebGeolocationEventPort,
    isPrivate: boolean
  ): Promise<void> {
    const decision: PermissionDecision = await this.coordinator.decide(
      event.origin,
      WebResourceKind.GEOLOCATION,
      isPrivate
    );
    event.geolocation.invoke(event.origin, decision === PermissionDecision.ALLOW, !isPrivate);
  }
}
