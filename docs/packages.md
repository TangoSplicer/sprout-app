Decentralized Package Hosting Guide

### 📄 `docs/packages.md`
```markdown
# Sprout Package Hosting

Sprout packages are hosted **decentralized** — no central registry needed.

## 1. GitHub (Recommended)

Host your `.sprout` package as a raw file:

```
https://raw.githubusercontent.com/username/repo/main/package.sprout
```

In Sprout:
```sprout
import "mylib" from "github.com/username/repo"
```

## 2. IPFS

Upload your package to IPFS:

```bash
ipfs add package.sprout
# → QmXyZ123...
```

Use in Sprout:
```sprout
import "mylib" from "ipfs://QmXyZ123..."
```

## 3. Self-Hosted

Host on any static server:
```sprout
import "mylib" from "https://mysite.com/mylib.sprout"
```

## 4. Official Packages

Bundled with Sprout app:
```sprout
import "ui" from "@sprout/ui"
import "net" from "@sprout/net"
```

No backend. No fees. Just **open, peer-to-peer sharing**.
```