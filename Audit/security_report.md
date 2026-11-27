# ProtoGNOME Security & Quality Audit Report — v1.0.16 (`1.0.16-1` / `1.0.16+10`)

**Date:** November 27, 2026  
**Application:** ProtoGNOME (`v1.0.16` / `protognome_1.0.16-1_amd64.deb`, Build `1.0.16+10`)  
**Tools:** Snyk CLI (`v1.1309.0`), SonarQube Cloud (`TaliskerMan_ProtoGNOME`), Flutter Analyzer & Test (`3.50.1`), Syft (`1.54.0`), Grype, Trivy, OSV-Scanner, ShellCheck  
**Repository:** `TaliskerMan/ProtoGNOME`

---

## 1. Executive Summary

A multi-scanner security and quality audit was conducted on **ProtoGNOME v1.0.16** (`1.0.16+10`) per the Nordheim Online development standards (`~/sarules`).

| Gate / Audit Layer | Tool | Result | Details |
|---|---|---|---|
| **Snyk Code (SAST)** | `snyk code test` (`taliskerman`) | ✅ PASS | `0` Snyk Code issues across Dart, C++17, JavaScript ESM, and Shell |
| **SonarQube Cloud Quality Gate** | `TaliskerMan_ProtoGNOME` (`main`) | ✅ PASS | Quality Gate `OK` (`0` Bugs, `0` Vulnerabilities, `0` Security Hotspots, `0` Code Smells) |
| **Flutter Static Analysis & Tests** | `flutter analyze` + `flutter test` | ✅ PASS | `0` analyzer issues, `32 / 32` unit & security tests passed |
| **Shell & Guide Static Analysis** | `shellcheck` + `bash -n` + `node --check` | ✅ PASS | `0` warnings across `build_release.sh` and `docs/guide/build_guide.js` |
| **Supply Chain & Secrets (`CP-SBOM`)** | `syft`, `grype`, `osv-scanner`, `trivy` | ✅ PASS | Path-sanitized CycloneDX SBOM (`Audit/SBOM-Linux.json`); `0` vulnerabilities, `0` secrets, `0` host workstation paths |

---

## 2. Security Safeguards & Integrity Protections

- **Mandatory Dual Download Verification:** Every GE-Proton and Luxtorpeda archive must match both its publisher checksum (`.sha512sum`, `.sha256sum`, `.sha512`, or `.sha256`) and GitHub's recorded SHA-256 asset digest before extraction; unverifiable releases are refused without an Install button.
- **Archive & Subprocess Hardening:** ZIP members are checked with `path.isWithin`, `.tar.gz`/`.tar.xz` archives are inspected prior to extraction to reject absolute paths and `..` traversal entries, `tar` is invoked via structured argument arrays (never `bash -c`), staging uses private `Directory.systemTemp` directories, and downloads above 4 GiB are aborted.
- **Read-Only Steam Inspection & Keyring Secrets:** Steam `config.vdf` and `libraryfolders.vdf` are parsed strictly read-only. Optional GitHub PATs are stored in the desktop `libsecret` keyring rather than plaintext SQLite.
- **Sanitized Owner-Only Logging (`CP-Logging`):** `~/.local/state/protognome/app.log` strips CR/LF characters (`LoggerService.sanitize`), sets `0600` owner-only permissions, and rotates automatically at 5 MiB.
- **Cryptographic Packaging & Attribution (`L-DEB-Packaging`, `L-Release`, `CP-AboutPage`):** `protognome_1.0.16-1_amd64.deb` is built rootlessly (`dpkg-deb --root-owner-group`), signed with maintainer key `Chuck Talk <chuck@nordheim.online>` (`D60BA098CDA22A20BD8BB6834E99214B22CFEE40`), hashed with SHA-512/SHA-256, and archived in `~/NOBuilds/ProtoGNOME-11-27-2026-1.0.16/`.
