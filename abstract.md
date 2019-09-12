Recovering from a Split Brain with Pg_xlogdump and Pg_rewind
---

Suppose you run PostgreSQL in a high-availability environment. What happens when you failover to your replica but STONITH fails and writes continue to occur on the old primary?

Suffering from a split-brain with diverging timelines is a terrifying event for any engineer in this scenario. But we can use core PostgreSQL tooling to figure out exactly what changes committed after the timelime divergence.

In this talk I'll demo investigating the divergence of data in such a scenario using pg_xlogdump (and some custom scripting). After we know how the two primary nodes diverged, I'll use pg_rewind to bring the old primary back into sync with the new primary and establish it as the new synchronous replica.
