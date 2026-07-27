# Contributing

Before opening a change, run:

```bash
moon fmt --check
moon check --target all --deny-warn --warn-list +73
moon build --target all --deny-warn
moon test --target all --deny-warn
moon info
git diff --exit-code
moon package
```

New behavior should include a focused test. Keep public APIs documented and
do not add experimental ECMA-426 proposals to the v0.1 surface without a
separate design discussion. Third-party fixtures must retain their license,
source URL and pinned upstream revision.
