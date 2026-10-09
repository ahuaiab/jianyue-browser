import { describe, expect, it } from '@ohos/hypium';
import {
  normalizeSiteSearchTemplates,
  siteSearchSuggestionForInput,
  siteSearchTemplateFromForm,
  siteSearchTemplateMatchesUrl,
  siteSearchUrlFor,
  SiteSearchFormSnapshot,
  SiteSearchTemplate
} from '../../../main/ets/browser/model/SiteSearchModels';

function searchForm(): SiteSearchFormSnapshot {
  return {
    pageUrl: 'http://10.0.2.2:57721/search',
    pageTitle: 'Search',
    actionUrl: 'http://10.0.2.2:57721/search',
    method: 'GET',
    searchFieldName: 'q',
    searchFieldType: 'text',
    searchSemantic: true,
    hasPasswordField: false,
    hasSensitiveField: false,
    hiddenFields: [{ name: 'lang', value: 'zh' }]
  };
}

export default function siteSearchModelsTest() {
  describe('SiteSearchModels', () => {
    it('learns only a same-origin semantic GET search form', 0, () => {
      const template: SiteSearchTemplate | undefined = siteSearchTemplateFromForm(searchForm(), 100);
      expect(template === undefined).assertFalse();
      if (template !== undefined) {
        expect(template.origin).assertEqual('http://10.0.2.2:57721');
        expect(template.path).assertEqual('/search');
        expect(template.queryFieldName).assertEqual('q');
        expect(template.fixedFields.length).assertEqual(1);
      }
    });

    it('rejects POST, cross-origin, non-search and sensitive forms', 0, () => {
      const post: SiteSearchFormSnapshot = searchForm();
      post.method = 'POST';
      expect(siteSearchTemplateFromForm(post, 100)).assertUndefined();

      const crossOrigin: SiteSearchFormSnapshot = searchForm();
      crossOrigin.actionUrl = 'https://other.example/search';
      expect(siteSearchTemplateFromForm(crossOrigin, 100)).assertUndefined();

      const nonSearch: SiteSearchFormSnapshot = searchForm();
      nonSearch.searchSemantic = false;
      expect(siteSearchTemplateFromForm(nonSearch, 100)).assertUndefined();

      const malformedAuthority: SiteSearchFormSnapshot = searchForm();
      malformedAuthority.actionUrl = 'http://10.0.2.2:57721/' + String.fromCharCode(92) + 'search';
      expect(siteSearchTemplateFromForm(malformedAuthority, 100)).assertUndefined();

      const credentialForm: SiteSearchFormSnapshot = searchForm();
      credentialForm.hasSensitiveField = true;
      expect(siteSearchTemplateFromForm(credentialForm, 100)).assertUndefined();
    });

    it('replays the validated GET template and matches only its result route', 0, () => {
      const template: SiteSearchTemplate | undefined = siteSearchTemplateFromForm(searchForm(), 100);
      expect(template === undefined).assertFalse();
      if (template !== undefined) {
        const url: string = siteSearchUrlFor(template, '红楼梦');
        expect(url).assertEqual('http://10.0.2.2:57721/search?lang=zh&q=%E7%BA%A2%E6%A5%BC%E6%A2%A6');
        expect(siteSearchTemplateMatchesUrl(template, url)).assertTrue();
        expect(siteSearchTemplateMatchesUrl(template,
          'http://10.0.2.2:57721/search?lang=en&q=红楼梦')).assertFalse();
        expect(siteSearchTemplateMatchesUrl(template,
          'http://10.0.2.2:57721/other?lang=zh&q=红楼梦')).assertFalse();
        expect(siteSearchUrlFor(template, ' ')).assertEqual('');
      }
    });

    it('suggests a saved site template from an IP host alias', 0, () => {
      const template: SiteSearchTemplate | undefined = siteSearchTemplateFromForm(searchForm(), 100);
      expect(template === undefined).assertFalse();
      if (template !== undefined) {
        const suggestion = siteSearchSuggestionForInput('10.0.2.2 红楼梦', [template]);
        expect(suggestion === undefined).assertFalse();
        if (suggestion !== undefined) {
          expect(suggestion.url).assertEqual('http://10.0.2.2:57721/search?lang=zh&q=%E7%BA%A2%E6%A5%BC%E6%A2%A6');
          expect(suggestion.query).assertEqual('红楼梦');
        }
      }
    });

    it('ignores malformed persisted candidates and caps the template list', 0, () => {
      expect(normalizeSiteSearchTemplates([null] as Object).length).assertEqual(0);
      const template: SiteSearchTemplate | undefined = siteSearchTemplateFromForm(searchForm(), 100);
      expect(template === undefined).assertFalse();
      if (template !== undefined) {
        const templates: SiteSearchTemplate[] = [];
        for (let index: number = 0; index < 40; index += 1) {
          const candidate: SiteSearchTemplate = {
            id: template.id + '-' + index,
            siteName: template.siteName,
            origin: template.origin,
            path: template.path + '/' + index,
            queryFieldName: template.queryFieldName,
            fixedFields: template.fixedFields,
            lastUsedAt: index + 1
          };
          templates.push(candidate);
        }
        expect(normalizeSiteSearchTemplates(templates as Object).length).assertEqual(32);
      }
    });
  });
}
