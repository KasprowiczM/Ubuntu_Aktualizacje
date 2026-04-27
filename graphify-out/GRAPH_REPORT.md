# Graph Report - /home/mk/Dev_Env/Ubuntu_Aktualizacje  (2026-04-27)

## Corpus Check
- 10 files · ~25,600 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 161 nodes · 430 edges · 9 communities detected
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 71 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]

## God Nodes (most connected - your core abstractions)
1. `DevSyncError` - 31 edges
2. `import_overlay()` - 19 edges
3. `export_candidates()` - 17 edges
4. `verify_full_state()` - 17 edges
5. `safe_relpath()` - 15 edges
6. `load_config()` - 15 edges
7. `classify_repo()` - 15 edges
8. `Logger` - 14 edges
9. `normalize_relpath()` - 14 edges
10. `main()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `StaticDevSyncConfigTests` --uses--> `DevSyncError`  [INFERRED]
  /home/mk/Dev_Env/Ubuntu_Aktualizacje/tests/test_dev_sync_safety.py → /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_core.py
- `DevSyncError` --uses--> `FileProviderStatus`  [INFERRED]
  /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_core.py → /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_proton_status.py
- `DevSyncError` --calls--> `manifest_files()`  [INFERRED]
  /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_core.py → /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_proton_status.py
- `DevSyncError` --calls--> `main()`  [INFERRED]
  /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_core.py → /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_proton_status.py
- `DevSyncError` --calls--> `main()`  [INFERRED]
  /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_core.py → /home/mk/Dev_Env/Ubuntu_Aktualizacje/dev-sync/dev_sync_purge_quarantine.py

## Communities

### Community 0 - "Community 0"
Cohesion: 0.11
Nodes (30): Classification, classify_repo(), compare_overlay_content(), config_defaults(), content_check_is_sensitive(), detect_proton_drive_path(), directory_exclude_patterns(), dirty_tracked_entries() (+22 more)

### Community 1 - "Community 1"
Cohesion: 0.17
Nodes (11): create_provider(), export_candidates(), ExportResult, git_output(), import_overlay(), ImportResult, LocalFileSystemProvider, RCloneProvider (+3 more)

### Community 2 - "Community 2"
Cohesion: 0.16
Nodes (19): log_section(), Logger, require_local_provider(), RunOptions, build_parser(), evaluate_path(), expected_paths(), FileProviderStatus (+11 more)

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (18): copy_relpaths(), DevSyncError, manifest_path(), re_drive_path(), read_json(), read_manifest(), remove_path(), resolve_under() (+10 more)

### Community 4 - "Community 4"
Cohesion: 0.14
Nodes (16): config_path(), ConfigReviewRequired, create_default_config(), DevSyncConfig, load_config(), print_config_hint(), repo_root_from_script(), build_parser() (+8 more)

### Community 5 - "Community 5"
Cohesion: 0.3
Nodes (13): lexists(), list_files_in_directory(), normalize_relpath(), path_is_under_roots(), path_matches_pattern(), build_plan(), collect_prune_candidates(), is_protected_relpath() (+5 more)

### Community 6 - "Community 6"
Cohesion: 0.22
Nodes (1): CloudProvider

### Community 7 - "Community 7"
Cohesion: 0.5
Nodes (1): StaticDevSyncConfigTests

### Community 8 - "Community 8"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **Thin community `Community 8`** (1 nodes): `__init__.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `DevSyncError` connect `Community 3` to `Community 0`, `Community 1`, `Community 2`, `Community 4`, `Community 6`, `Community 7`?**
  _High betweenness centrality (0.202) - this node is a cross-community bridge._
- **Why does `CloudProvider` connect `Community 6` to `Community 0`, `Community 1`?**
  _High betweenness centrality (0.088) - this node is a cross-community bridge._
- **Why does `load_config()` connect `Community 4` to `Community 0`, `Community 2`, `Community 3`?**
  _High betweenness centrality (0.068) - this node is a cross-community bridge._
- **Are the 9 inferred relationships involving `DevSyncError` (e.g. with `NullLogger` and `DevSyncPathSafetyTests`) actually correct?**
  _`DevSyncError` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `safe_relpath()` (e.g. with `.test_safe_relpath_rejects_escape_paths()` and `.test_safe_relpath_keeps_normal_project_paths()`) actually correct?**
  _`safe_relpath()` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._