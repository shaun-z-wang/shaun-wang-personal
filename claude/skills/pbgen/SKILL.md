---
name: pbgen
description: Run pbgen to generate code from proto files in the carrot monorepo. Use when the user says /pbgen or asks how to run pbgen, regenerate protos, or generate protobuf code.
---

# Run pbgen for Proto Files

Generate Go, Ruby, and Python code from `.proto` files in the carrot monorepo using `pumpkin pbgen`.

## Prerequisites

1. Each proto file must have the `go_package` option set:
   ```
   option go_package = "github.com/instacart/carrot/pbgen/pbgen-go/instacart/<path to app>/v1;<packagename>";
   ```

2. An empty `.pbgen` file must exist in the proto directory to signal code generation:
   ```bash
   touch ~/carrot/shared/protos/<path to app>/v1/.pbgen
   ```
   To exclude a subdirectory, add a `.pbgenskip` file instead.

## Running pbgen

From anywhere inside `~/carrot/`:

```bash
ic pumpkin pbgen
```

- No arguments or flags needed — it processes **all** directories under `shared/protos` that contain a `.pbgen` file.
- Generates code in all supported languages (Go, Ruby, Python).
- Takes ~3 minutes on the full carrot repo. This is normal.

## Recommended Commit Workflow

1. Lint first: `ic pumpkin lint`
2. Commit proto changes separately:
   ```bash
   git add ~/carrot/shared/protos
   git commit -m "Update proto files: <description>"
   ```
3. Run pbgen: `ic pumpkin pbgen`
4. Commit generated code separately:
   ```bash
   git add ~/carrot/pbgen
   git commit -m "Regenerate pb types"
   ```

Separating proto and generated code commits helps with code review.

## Troubleshooting

- If pbgen warns about missing `go_package`, add it to the proto file and retry.
- If pbgen fails, discard all pbgen changes and fix the proto issues before retrying.
- If proto imports fail, ensure imported protos are also set up for pbgen.
- For help, ask in **#eng-pumpkin** on Slack.

## References

- [pumpkin pbgen (Confluence)](https://instacart.atlassian.net/wiki/spaces/ENG/pages/3362652494)
- [Steps to add/change proto (Confluence)](https://instacart.atlassian.net/wiki/spaces/Fulfillment/pages/5170200601)
- [managing-protobuf SKILL.md (GitHub)](https://github.com/instacart/claude-marketplace/blob/master/protos/skills/managing-protobuf/SKILL.md)
