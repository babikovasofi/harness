# RU anti-AI-slop checklist

RU-priority layer on top of the EN `banned-words.md`. ~70% of EN rules (em-dash, Title Case, copula-avoidance) don't map to Russian — these are the RU markers. Sourced via deep research (designers/copywriters 2025-2026, PNAS Reinhart 2025).

## Why slop is caught (fix mechanics, not single words)
1. **Perplexity** — predictability of next word (AI = too low).
2. **Burstiness** — variance in sentence length/structure (AI = flat).
3. **Morphology (RU)** — LLMs chain genitive case, participle/gerund tails and nominalizations 2-5× more than humans.

## KILL-LIST (delete on sight)
- **A. Empty openings** — «В современном мире», «В эпоху, когда», «Ни для кого не секрет». First paragraph removable without losing a fact → cut, start on the fact.
- **B. Value-inflation without a number** — «играет ключевую роль», «выводит на новый уровень», «мощный/передовой/инновационный», «бесшовно». Every value claim carries a number or dies.
- **C. Канцелярит / nominalizations** (top RU marker) — «осуществляет реализацию»→«реализует», «производит обработку»→«обрабатывает». Kill «данный / является / представляет собой / осуществляется». Break genitive chains.
- **D. Participle/gerund tails** — «…, обеспечивая рост и привлекая клиентов», «…, что позволяет повысить». Rewrite as separate verbs or delete.
- **E. Hedging stacks** — «важно отметить», «стоит подчеркнуть», «как правило» (без конкретики). Max one hedge, ideally zero. Keep only *precise* hedges («не тестировали на объёмах >1М SKU»).
- **F. Fake balance** — «не просто X, а Y», «больше, чем просто», «с одной стороны… с другой» without a real other side. Use the affirmative form.
- **G. Tricolons** — «быстро, надёжно, удобно». One per text max.
- **H. Plastic empathy** — «Мы понимаем, как трудно», «Представьте ситуацию». Replace with the concrete problem.
- **I. Chatbot closers** — «В заключение», «Подводя итог», «Таким образом». Summary echoing the intro → delete. End on the last fact.
- **J. AI list structure** — bold-term + dash + equal-length obvious gloss, emoji bullets. Rewrite to prose or uneven-length essentials.
- **K. Punch-up dashes** — dash is legit in RU, but not dash-for-drama before an abstraction-uplift. Use a comma/period.

## VOICE-POSITIVES (write instead)
1. Verb first: «Подбирает SKU под спрос», not «Является решением для…».
2. Concrete nouns/names: «Ozon Fresh», «оборачиваемость», a real API/metric — not «современные технологии».
3. Name the thing: a 14-day demand forecast → say so, not «интеллектуальная аналитика».
4. Rule/fact first, justification second.
5. A number in every paragraph that can carry one.

## SENTENCE-RHYTHM (burstiness)
Per paragraph: at least one sentence < 6 words and one > 25. Never two long in a row. Read aloud — out of breath → cut.

## 3-PASS ROUTINE (run per file)
- **PASS 1 — strip tails.** Delete abstract opening + moralizing closer. No new conclusion, no CTA boilerplate.
- **PASS 2 — hostile critique.** Number every A-K hit + sentences droppable whole + abstractions without specifics.
- **PASS 3 — rewrite.** ≥3 abstractions → numbers/concrete nouns; nominalizations → verbs; genitive chains split; enforce <6 / >25 rhythm; affirmative form over «не просто X, а Y».

## GUARD against over-editing
Slop is cured by concreteness + uneven rhythm, NOT by deleting all connectives or telegraphing. Keep precise hedges, one working tricolon/dash, some long subordinate sentences. Done = reads like a domain expert wrote it, not «clean but empty».
