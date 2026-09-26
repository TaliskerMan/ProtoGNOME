## What's Changed in v1.0.13

### Fixes & Enhancements
- **Chunk File Isolation in Parallel Downloader:** Resolved file corruption and checksum failures by isolating concurrent byte range chunks into individual `.partN` temporary files. Previously, concurrent streams opened the destination file simultaneously with `FileMode.writeOnly`, causing file truncation and zero-filled gaps.
- **Strict HTTP 206 Verification:** Enforced HTTP `206 Partial Content` validation for all chunk requests, properly rejecting servers or proxies returning HTTP 200 that ignore `Range` headers.
- **CDN Redirect Handling:** Disabled automatic redirect following on the initial HEAD probe (`followRedirects = false`), correctly capturing 302 `location` headers from edge CDNs (e.g. `objects.githubusercontent.com`).
- **Part File Assembly & Cleanup:** Guaranteed in-order stream assembly into the final destination file and guaranteed deletion of temporary part files in `finally` blocks upon completion or failure.
- **Archive Extraction Error Logging:** Added `_tarOk` helper logging `stderr` output to `LoggerService` when archive extraction encounters errors.

### Quality & Security Audits
- **Unit Testing:** Added unit tests verifying 6-chunk large file (>100 MB) partitioning and byte range continuity. Full unit test suite passes with 100% success.
- **Semgrep SAST:** Ran Semgrep security audit across all first-party Dart sources (47 rules) with 0 findings.
- **SonarQube:** Passed SonarQube quality gate (Status: OK, Clean as You Code: Compliant, 0 new violations).
- **Supply Chain & SBOM:** CycloneDX SBOM generated and validated; package signed with GPG key.

### Verification & Checksums
- `protognome_1.0.13-1_amd64.deb` signed with GPG key `chuck@nordheim.online` (`D60BA098CDA22A20BD8BB6834E99214B22CFEE40`).
- SHA256 and SHA512 hash digests provided for standalone verification.

Maintainer: Chuck Talk <chuck@nordheim.online>
