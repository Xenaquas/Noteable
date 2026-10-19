# Noteable publication record

**19 October 2026 | Application source and review archive**

The Flutter project and its review collection are published in [Xenaquas/Noteable](https://github.com/Xenaquas/Noteable). The matching document and evidence backup is in the [Noteable Google Drive folder](https://drive.google.com/drive/folders/1shOANlSI-cA5TOSGWvVxvdUsPGzpNszt).

The application implementation and the wording of the 18 review Markdown sources are preserved. The reports describe the review baseline before publication. Statements in those reports about Git not yet being initialized refer to that earlier review; this record documents the subsequent publication.

## Version history

| Record | Commit | Contents |
|---|---|---|
| Repository initialization | `3cc73d85016e3879cce58a19a0d8a94563b8f163` | Existing review README |
| Application and review snapshot | `b2bd2c35196125a78d2be0d82d8166fb659f020f` | Complete 392-file source tree, 18 Word files, Markdown, diagrams and evidence |
| Publication ledger | The commit containing this record | File manifest, QA summary and publication validation utility |

The snapshot tree is `642ab2d3c9eca79f8b6eb59065ac162f22333804`. The GitHub tree matched the staged local Git tree exactly. Every binary Git object was checked against its staged Git object hash. No existing remote history was overwritten; branch updates used the previously observed head as a lease.

The project had no Git history on arrival. These commits establish the starting point for future version comparisons. The local `main` branch tracks `origin/main` at `https://github.com/Xenaquas/Noteable.git`.

## Artifact collection

| Collection | Local source | Drive location | Count |
|---|---|---|---:|
| Current Word reports including README | `docs/documents/current/` | [Documents / Current Reports](https://drive.google.com/drive/folders/18lv5s4hN9VS9Hlf-7Z9a67BLjMl6EMsh) | 13 |
| Historical Word documents | `docs/documents/archive/` | [Documents / Archive](https://drive.google.com/drive/folders/1gXX5TbGt50RpRxpHVKS8rxgMObYz2sNs) | 5 |
| Review Markdown and archived plans | Root README, `docs/*.md`, `docs/archive/` | [Markdown](https://drive.google.com/drive/folders/1r19VbhLBDe3rsaF2rzPROUs-N0pq7KC9) | 18 |
| Diagram PNG and Mermaid sources | `docs/diagrams/` | [Diagrams](https://drive.google.com/drive/folders/14cmuxttaO9RiaJUP5y07P9htdm3F4JPL) | 3 |
| Original Android captures | `docs/evidence/screenshots/` | [Evidence / screenshots](https://drive.google.com/drive/folders/1JV_DU3PkT0zj-O9akHUIoo67x4UepW__) | 35 |
| Runtime and build records | `docs/evidence/logs/` | [Evidence / logs](https://drive.google.com/drive/folders/1JEF9GEgtyUFHG5v0y_GuaXHKLqJLd4lS) | 95 |
| Synthetic fixtures | `docs/evidence/fixtures/` | [Evidence / fixtures](https://drive.google.com/drive/folders/10HjqVZvfEqAeuA1JGpZ31qdOZnfa0BoL) | 2 |
| Evidence manifests and utilities | `docs/evidence/` | [Evidence](https://drive.google.com/drive/folders/1ESNcyvwiTW3m0WP6ww6eCWG9vyK8oUP4) | 5 |
| Publication records and document utilities | `docs/publication/` | [Records](https://drive.google.com/drive/folders/1xBZEm-nTFPU6Ye9Xy47pmOXU0YVErkLS) | See receipt |

The primary backup contains 176 files. Publication records are additional files. The Drive-only `PUBLICATION_RECEIPT.json` in Records identifies the final ledger commit and uploaded record files after publication finishes. The [Drive manifest](drive-file-manifest.json) maps every primary artifact to its original project path, Drive file ID, folder, URL, byte size and local SHA256. Drive folder readback verified IDs, names and sizes; the connector does not expose cloud checksums.

The editable [tldraw board](https://www.tldraw.com/f/MJ8ymcLzU-nKT2TWyaEVd) remains available. Its existing PNG and Mermaid source files are backed up. Mermaid files are stored in Drive as plain text rather than the unrelated chemical MIME type associated with the `.mmd` extension.

## Document quality and preservation

The Word collection contains 106 final pages and 59 embedded image instances. It uses Word heading styles, numbered and bulleted lists, readable tables with repeating headers, source hyperlinks, figure descriptions and screenshot captions. Architecture and workflow details have enlarged landscape pages. The feature report was repaginated to remove a one-line trailing page.

All final page images were opened for visual inspection. The supplied Documents renderer reported that LibreOffice was unavailable, so the files were exported read-only through Microsoft Word 16 and rasterized with bundled Python and Poppler at 110 DPI. Temporary PDF and page PNG outputs are internal QA files and are excluded from the published collection. Original screenshot files are retained separately.

The [QA summary](qa-summary.json) and [document manifest](document-manifest.json) record the final files, source hashes and page counts. Validation confirmed:

- All 65 application and test Dart files match the review inventory, locally and in the published Git commit.
- All 35 original screenshot hashes match their evidence manifest.
- All 18 review Markdown source hashes remain unchanged.
- Every embedded proof image matches an original screenshot or the original diagram PNG.
- Each Word file has one black document title, no decorative paragraph rules and descriptions for embedded figures.
- `README.md` remains the only Markdown file at the project root.

No application behavior was changed during publication. The existing analyzer findings, failing widget test and product defects remain as documented. The prior review's dependency and Android compatibility changes are included in the source baseline. Repository setup additionally excludes generated `android/build/` reports and includes the existing Gradle wrapper scripts and JAR; the Unix wrapper has executable mode in Git.

## Publication method

The connected GitHub account has write access to Noteable. The terminal GitHub CLI is signed in as `IsaShaikh`, which does not have push access to this repository. Publication therefore used the authorized GitHub connector; terminal credentials were not changed. Future terminal pushes require an account with repository write access. The local checkout was fetched and aligned to the published commit without rewriting working files.

Files were uploaded through the connected Google Drive account into the requested Noteable folder. Existing Drive sharing settings were retained.

## Maintaining the work record

1. Make each application fix on a focused branch and cite its review finding number.
2. Record the change, checks and resulting commit. Update the relevant current report only when the new behavior is verified.
3. Preserve the original review captures. Store later runtime evidence in dated subdirectories.
4. Commit source, Markdown, diagrams and regenerated Word files together when their content changes. Review the diff before publishing.
5. Update existing Drive file IDs when replacing an artifact so Drive revisions remain useful. Refresh the manifest and publish a dated receipt with the corresponding Git commit.
6. Use the Git history to compare or recover source versions. Keep application data recovery separate from source version control, as explained in the review.

To inspect this application snapshot without changing the current working directory, use a separate clone and select its recorded commit:

```powershell
git clone https://github.com/Xenaquas/Noteable.git Noteable-review
cd Noteable-review
git switch --detach b2bd2c35196125a78d2be0d82d8166fb659f020f
```

Document packaging and publication checks can be repeated with the included utilities. The validation utility requires the temporary Word export records when verifying page counts; the durable QA summary retains the completed result.
