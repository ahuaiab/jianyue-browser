import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { readWebScriptJson } from './WebScriptJson';
import {
  ReaderModePreferences,
  ReaderModeResult,
  ReaderModeStatus,
  readerModePageEligibility
} from '../model/ReaderMode';

interface ReaderScriptBundle {
  runtime: string;
  readability: string;
  readerable: string;
  purifier: string;
}

type ReaderAction = 'probe' | 'enter' | 'exit' | 'preferences';

export class ReaderModeController {
  private readonly context: common.UIAbilityContext;
  private scriptsPromise: Promise<ReaderScriptBundle> | undefined;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  probe(controller: webview.WebviewController, expectedUrl: string): Promise<ReaderModeResult> {
    return this.execute(controller, 'probe', expectedUrl);
  }

  enter(
    controller: webview.WebviewController,
    expectedUrl: string,
    preferences: ReaderModePreferences
  ): Promise<ReaderModeResult> {
    return this.execute(controller, 'enter', expectedUrl, preferences);
  }

  exit(controller: webview.WebviewController, expectedUrl: string): Promise<ReaderModeResult> {
    return this.execute(controller, 'exit', expectedUrl);
  }

  applyPreferences(
    controller: webview.WebviewController,
    expectedUrl: string,
    preferences: ReaderModePreferences
  ): Promise<ReaderModeResult> {
    return this.execute(controller, 'preferences', expectedUrl, preferences);
  }

  private loadScripts(): Promise<ReaderScriptBundle> {
    if (this.scriptsPromise !== undefined) {
      return this.scriptsPromise;
    }
    this.scriptsPromise = Promise.all([
      this.readRawFile('reader/reader-runtime.js'),
      this.readRawFile('reader/Readability.js'),
      this.readRawFile('reader/Readability-readerable.js'),
      this.readRawFile('reader/purify.min.js')
    ]).then((values: Array<string>) => {
      const bundle: ReaderScriptBundle = {
        runtime: values[0],
        readability: values[1],
        readerable: values[2],
        purifier: values[3]
      };
      return bundle;
    }).catch((error: Object) => {
      this.scriptsPromise = undefined;
      throw new Error('reader-resource-load-failed');
    });
    return this.scriptsPromise;
  }

  private readRawFile(path: string): Promise<string> {
    return new Promise<string>((resolve: (value: string) => void, reject: (reason: Object) => void) => {
      this.context.resourceManager.getRawFileContent(path, (error: BusinessError, bytes: Uint8Array) => {
        if (error) {
          reject(error);
          return;
        }
        try {
          const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
          resolve(decoder.decodeToString(bytes));
        } catch (decodeError) {
          reject(decodeError as Object);
        }
      });
    });
  }

  private async execute(
    controller: webview.WebviewController,
    action: ReaderAction,
    expectedUrl: string,
    preferences: ReaderModePreferences = { textSize: 'standard', theme: 'white' }
  ): Promise<ReaderModeResult> {
    const eligibility = readerModePageEligibility(expectedUrl);
    if (!eligibility.eligible && action !== 'exit') {
      return { status: 'unavailable', available: false, active: false, reason: eligibility.reason };
    }
    try {
      const bundle: ReaderScriptBundle = await this.loadScripts();
      const moduleFactory = (source: string): string => {
        return '(function(){const module={exports:{}};const exports=module.exports;\n' +
          source + '\n;return module.exports;})()';
      };
      const script: string =
        '(function(){' +
        'const Readability=' + moduleFactory(bundle.readability) + ';' +
        'const isProbablyReaderable=' + moduleFactory(bundle.readerable) + ';' +
        'const DOMPurify=' + moduleFactory(bundle.purifier) + ';' +
        'const run=' + bundle.runtime + ';' +
        'return run(' + JSON.stringify(action) + ',' + JSON.stringify(expectedUrl) + ',' +
          JSON.stringify(preferences) + ',{Readability:Readability,isProbablyReaderable:isProbablyReaderable,' +
          'DOMPurify:DOMPurify});' +
        '})()';
      const rawResult: string | null = await controller.runJavaScript(script);
      if (rawResult === null || rawResult.length === 0) {
        return { status: 'error', available: false, active: false, reason: 'empty-script-result' };
      }
      return this.parseResult(rawResult);
    } catch (_error) {
      return { status: 'error', available: false, active: false, reason: 'reader-script-failed' };
    }
  }

  private parseResult(value: string): ReaderModeResult {
    try {
      const decoded: Object | undefined = readWebScriptJson(value);
      if (decoded === undefined || Array.isArray(decoded)) {
        return { status: 'error', available: false, active: false, reason: 'invalid-script-result' };
      }
      const parsed: Record<string, Object> = decoded as Record<string, Object>;
      const rawStatus: Object | undefined = parsed['status'];
      const status: ReaderModeStatus = rawStatus === 'active' || rawStatus === 'unavailable' ||
        rawStatus === 'available' ? rawStatus as ReaderModeStatus : 'error';
      const rawReason: Object | undefined = parsed['reason'];
      return {
        status,
        available: parsed['available'] === true,
        active: parsed['active'] === true,
        reason: typeof rawReason === 'string' ? rawReason : ''
      };
    } catch (_error) {
      return { status: 'error', available: false, active: false, reason: 'invalid-script-result' };
    }
  }
}
