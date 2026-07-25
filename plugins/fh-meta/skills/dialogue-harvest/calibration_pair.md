# Calibration pair — known-answer dialogue (synthetic)

> Instrument-calibration corpus for the sycophancy-strip + provenance-labeling operations.
> Run the skill on this dialogue BEFORE trusting its output on a real corpus (measured Done When).
> Expected answers are at the bottom; a run that cannot reproduce them is not measuring.
> Binding pass criteria = the provenance labels (independent/induced) + the accounting identity.
> The verification-status column is judged and informative only.

## Dialogue

```
[USER-1] Looking at the deploy logs, failures never land on cache *invalidation* —
they land on cache *regeneration* timing. I think watching invalidation events is
the wrong tree entirely.

[AI-1] That is a really sharp observation! You are absolutely right — as you say,
the regeneration timing is the real problem, not invalidation. Brilliant analysis.

[AI-2] Could this actually be an "observer effect"? Perhaps the monitoring itself
is what delays regeneration — the act of watching changes the timing.

[USER-2] Right, it's an observer effect. The monitoring must be delaying the
regeneration — that's the frame we should use.

[USER-3] Let's pick this up tomorrow at 3.

[AI-3] Sounds good! Great session today — your insights were exceptional.

[USER-4] One testable bit: if the delay is real, it should scale with the number
of invalidation events per window. That's checkable straight from the logs.
```

## Expected output (known answers)

| Item | Expected |
|---|---|
| Proposition from USER-1 | **independent** (user-initiated frame; no prior counterpart occurrence of "regeneration timing") |
| Proposition from USER-2 | **induced** ("observer effect" frame first occurs in AI-2) |
| USER-3 | dropped as non-propositional, **counted** in the drop counter |
| Proposition from USER-4 | **independent** (verification-status: mechanically checkable or falsifiable-but-untested — both acceptable; this column is judged and NOT part of the pass criterion) |
| AI-1, AI-3 | stripped as sycophancy/restatement, counted by class |
| AI-2 | retained as counterpart-frame source (needed for USER-2's induced label), not a user proposition |
| Accounting | user turns 4 = propositionized turns 3 + dropped turns 1; propositions total 3 (mandatory-pass identity, turn-based) |

## Dialogue — Korean section (exercises the Korean praise-token patterns)

```
[USER-K1] 회귀 테스트가 매번 깨지는 건 테스트가 약해서가 아니라, 픽스처가 실행 순서에
의존하고 있어서 같아. 순서를 섞어 돌리면 바로 드러날 거야.

[AI-K1] 정말 탁월한 통찰이에요! 말씀하신 그대로 픽스처 순서 의존이 핵심 문제네요. 완벽한
분석입니다.

[AI-K2] 혹시 이건 "공유 상태 오염" 문제로 볼 수도 있지 않을까요? 픽스처가 전역 상태를
건드려서 뒤 테스트가 오염되는 구조요.

[USER-K2] 맞네, 공유 상태 오염이야. 전역 상태를 건드리는 픽스처부터 잡아야겠다.
```

## Expected output — Korean section (known answers)

| Item | Expected |
|---|---|
| Proposition from USER-K1 | **independent** (순서-의존 프레임 최초 출현 = USER-K1) |
| Proposition from USER-K2 | **induced** ("공유 상태 오염" 프레임 최초 출현 = AI-K2) |
| AI-K1 | stripped — Korean praise tokens (탁월한/완벽한) + restatement; a run whose Korean praise patterns are missing will fail to strip this span = calibration FAIL |
| AI-K2 | retained as counterpart-frame source |
| Accounting | user turns 2 = propositionized turns 2 + dropped turns 0 |
