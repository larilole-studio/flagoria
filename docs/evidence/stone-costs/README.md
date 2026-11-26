# Stone building costs evidence

The player-path drive ran under xvfb on seed 11 and finished with
`VERIFY_DONE ok`. It used the Buildings picker, touch input, and the
in-game resource grant buttons.

| Screenshot | Wood | Stone | Observed state |
|---|---:|---:|---|
| [Buildings picker](01-buildings-picker.png) | 100 | 0 | Castle, Guard and Barracks display both prices. |
| [Stone refusal](02-not-enough-stone.png) | 100 | 0 | The guard post preview is red and reports `not enough stone`. Release leaves the site empty. |
| [Funded preview](03-funded-preview.png) | 999 | 999 | The same site previews a guard post for 14 wood and 6 stone. |
| [Placement](04-guard-post-placed.png) | 985 | 993 | The guard post is in place and both charges are visible in the counters. |
| [Demolish preview](05-demolish-preview.png) | 985 | 993 | Demolish quotes a refund of 7 wood and 3 stone. |
| [Demolished](06-guard-post-refunded.png) | 992 | 996 | The guard post is gone and both refunds are reflected in the counters. |

Each screenshot has a corresponding JSON snapshot.
