Reader runtime third-party assets

Mozilla Readability 0.6.0, commit ab4027a8b37669745016869a37a504727992b2ba:
https://github.com/mozilla/readability
Apache-2.0; see Readability-LICENSE.md and Readability-NOTICE.txt.

DOMPurify 3.4.16, commit 18f8f0e3d8efe7e3c8d3d2679aebd0df72164ead:
https://github.com/cure53/DOMPurify
Used under Apache-2.0; see DOMPurify-LICENSE.txt.

These scripts are bundled locally. Exact upstream URLs, versions and SHA-256 hashes are recorded in vendor-manifest.json. Readability extracts article content; DOMPurify sanitizes it before rendering. reader-runtime.js is project integration code.