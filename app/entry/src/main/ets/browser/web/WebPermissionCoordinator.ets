export enum WebResourceKind {
  CAMERA = 'camera',
  MICROPHONE = 'microphone',
  GEOLOCATION = 'geolocation',
  UNSUPPORTED = 'unsupported'
}

export enum PermissionDecision {
  ALLOW = 'allow',
  DENY = 'deny'
}

/** Resource names emitted by ArkWeb's PermissionRequest callback. */
export function webResourceKindForProtectedResource(resource: string): WebResourceKind {
  switch (resource) {
    case 'TYPE_VIDEO_CAPTURE':
      return WebResourceKind.CAMERA;
    case 'TYPE_AUDIO_CAPTURE':
      return WebResourceKind.MICROPHONE;
    // ArkWeb handles real geolocation through onGeolocationShow. Keep this
    // mapping for forward-compatible runtimes that expose it as a resource.
    case 'TYPE_GEOLOCATION':
      return WebResourceKind.GEOLOCATION;
    default:
      return WebResourceKind.UNSUPPORTED;
  }
}

export interface WebPermissionRequestPort {
  getOrigin(): string;
  getAccessibleResource(): Array<string>;
  grant(resources: Array<string>): void;
  deny(): void;
}

export interface WebGeolocationPort {
  invoke(origin: string, allow: boolean, retain: boolean): void;
}

export interface WebGeolocationEventPort {
  origin: string;
  geolocation: WebGeolocationPort;
}

export interface WebPermissionRequestHandler {
  onPermissionRequest(request: WebPermissionRequestPort, isPrivate: boolean): void;
  onGeolocationShow(event: WebGeolocationEventPort, isPrivate: boolean): void;
}

export interface PermissionPromptPort {
  confirm(origin: string, resource: WebResourceKind, isPrivate: boolean): Promise<PermissionDecision>;
}

/** Per-process permission memory. Private and ordinary tabs never share a
 * remembered decision, and unsupported resources are denied by default. */
export class WebPermissionCoordinator {
  private readonly normalDecisions: Map<string, PermissionDecision> = new Map();
  private readonly privateDecisions: Map<string, PermissionDecision> = new Map();
  private readonly prompt: PermissionPromptPort;

  constructor(prompt: PermissionPromptPort) {
    this.prompt = prompt;
  }

  async decide(origin: string, resource: WebResourceKind, isPrivate: boolean): Promise<PermissionDecision> {
    if (resource === WebResourceKind.UNSUPPORTED) {
      return PermissionDecision.DENY;
    }
    const decisions: Map<string, PermissionDecision> = isPrivate
      ? this.privateDecisions
      : this.normalDecisions;
    const key: string = `${origin}|${resource}`;
    const known: PermissionDecision | undefined = decisions.get(key);
    if (known !== undefined) {
      return known;
    }
    let decision: PermissionDecision = PermissionDecision.DENY;
    try {
      decision = await this.prompt.confirm(origin, resource, isPrivate);
    } catch (_error) {
      decision = PermissionDecision.DENY;
    }
    decisions.set(key, decision);
    return decision;
  }
}
