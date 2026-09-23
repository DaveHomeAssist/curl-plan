# CurlPlan reconciles its account foundation and speeds up the product preview

**For release after the integration pull request is merged and deployment proof is green.**

CurlPlan has completed the first Now-phase engineering package: the divergent account-foundation work is reconciled against the current application architecture, and the public product preview has a faster, clearer first experience.

The integration preserves current main as the source of truth. Account, backend, persistence, recovery, relationship, shared-object, moderation, and synchronization contracts were adapted to the current AppState model rather than replacing newer store and parity work. The resulting integration head includes 18 passing Swift contract tests plus a successful iOS simulator build.

The public preview now self-hosts its typography, removes Google Fonts from the critical path, presents one clear product heading and demo action, and improves keyboard focus, reduced-motion behavior, and 44px interaction targets. The preview remains credential-free and says so directly.

This is an engineering foundation release, not a public account launch. The included credential backend is restricted to development proof. Production identity will require managed authentication, recovery and deletion proof, abuse controls, migration testing, and signed-in cross-device verification before the account UI can ship.

The repository also gains pinned dependency, secret, and configuration scanning; weekly dependency updates; a changelog; and an evidence-based release checklist.
