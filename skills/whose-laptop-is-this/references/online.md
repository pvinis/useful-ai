# The opt-in enrichment branch

A **bounded, corroborated, one-pass** lookup. Off by default. Never runs before
the card has been printed, and never without an explicit yes in this run.

Read this file only when the offer fires — no channel reaches `strong` (the
reach-line predicate) **and** the sendable set is non-empty — or when the finder
asks for `--online` outright.

## The sendable set

Exactly three kinds may leave this machine:

| kind | example | sourced from |
|---|---|---|
| full name | `John Appleseed` | login account real-name fields |
| email | `john@appleseed.dev` | git config, Apple ID, MSA/OneDrive |
| corroborated handle | `github.com/jappleseed` | git remote, gh or ssh config |

A **corroborated handle** is one backed by a service reference on the machine. A
bare local account username is *not* a handle and is never sent — on most sites
it is a different person.

**Never sent**, each for its own reason:

- **Anything from the banner.** It is frequently a *third party's* phone or email
  — a partner, a colleague — who is not the owner and had no part in this. It is
  already a direct channel, so a lookup adds nothing and risks profiling a
  bystander. This is the sharpest line here: every other exclusion protects the
  owner, this one protects someone who is not even a party to the situation.
- **Serial number, hostname, MDM org, work tenant.** These identify the device or
  the employer, not the owner. A serial in a search box is closer to a
  stolen-goods lookup than to a return.
- **Work UPN.** Leaks where they work to a third party; a lookup on their name
  reaches the same place without it.
- **Phone numbers**, from any source.

## Query construction rule

A query's entire content must be **one allow-listed identifier value, verbatim,
one identifier per query**. Nothing else from the machine may appear in it — not
as extra terms, not as context, not as a filter.

    "John Appleseed"                          ← the whole query
    "John Appleseed" resume Acme 2019         ← forbidden

The second is a query built from the laptop's contents, even though no file was
uploaded. This is a **construction** rule, not a stated one, and deliberately so:
a stated rule gets talked around at 2am ("the hostname is basically an
identifier"), while a construction rule is checkable by reading the query string.
Laptop contents travel in the shape of a query as easily as in an upload.

## Sources

**Permitted:** a web search on an allowed identifier, and fetching the public
profile pages those results directly name (`github.com/<handle>`, a personal
site).

**Forbidden by name**, not merely unlisted: people-search aggregators and data
brokers (Pipl, Spokeo, WhitePages and equivalents), and any paid or regulated
lookup (reverse phone, address records). They aggregate what the owner never
published, which is the snooping this skill promises it is not doing — and
"public sources" is loose enough that an agent can argue a data broker is one, so
naming them removes the argument.

## Consent

Print verbatim, with the real values and their sources filled in, then wait. Do
not re-tone or expand it.

    The local search is done. A public lookup might turn up another way to reach them.

    Sent, if you say yes:

      name    John Appleseed          (this machine's login account)
      email   john@appleseed.dev      (this machine's git config)
      handle  github.com/jappleseed   (this machine's git remote)

    Nothing else from this laptop goes out — no files, no messages, no serial number,
    and nothing from the lock-screen note. The lookup is a web search plus the public
    profile pages those identifiers point at, run from this machine.

    Go ahead? (Or name just the ones you're happy to send.)

The per-line source annotation is what makes a narrowing reply usable — a finder
cannot sensibly drop the email without knowing it came from git config rather
than the owner's mail app. Honour a narrowing answer ("just the github one") by
sending only what was named.

On a decline, print `Fine — the card above is what the machine itself says.` and
stop. With no network, say so in one line and skip.

## Corroboration rule — the one test for keeping a result

Add an online channel only when the page it came from **independently carries a
second identifier already found on this machine** — the GitHub profile for that
handle lists that same git email, or that same full name. That is a real join.

Everything else is a name collision: **discard it silently**, do not mention it,
do not rank it. When nothing survives, print
`The lookup added nothing; the card above stands.`

Corroboration-or-nothing, rather than presenting candidates or hedging with a
`weak` tier: handing a finder a lineup of strangers is not a dossier, and every
wrong entry is an uninvolved person served up to someone holding a laptop. The
join test degrades gracefully to zero results; a confidence hedge does not.

## Budget: one pass

One query per allowed identifier, plus fetching the profile pages those results
directly name. Then stop. **Do not follow what those pages turn up into further
queries** — iteration is how a return-the-laptop lookup becomes an investigation
of a person. "Reasonable depth" is not reviewable; a fixed budget is.

## Merging

Online channels join the **single ranked list**, not a separate section, and the
card is reprinted whole rather than appended to. Each carries `online` in its
`kind · tier · why` line.

**Cap: `likely`** — an online channel rests on a cross-source identity join and
can never be `confirmed` or `strong`. The cap does the ranking work a hard "never
outranks a local channel" rule would, without pretending a strong online hit is
worse than a weak local one.

`--why` records the exact query issued and every URL fetched.
